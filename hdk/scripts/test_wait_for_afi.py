#!/usr/bin/env python3

# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================


if __name__ == "__main__":
    import os

    import coverage

    current_dir = os.path.dirname(os.path.abspath(__file__))
    cov = coverage.Coverage(source=[current_dir], omit=["*test*.py"])
    cov.start()

import sys
import unittest
from datetime import datetime, timedelta
from io import StringIO
from unittest.mock import Mock, patch

import boto3
from moto import mock_aws

# Import the module under test
from wait_for_afi import (
    DEFAULT_SNS_TOPIC,
    AFIWaiter,
    main,
    send_sns_notification,
    setup_sns_notification,
    wait_for_afi,
)


class TestAFIWaiter(unittest.TestCase):
    def setUp(self):
        self.afi_id = "afi-1234567890abcdef0"
        self.region = "us-east-1"
        self.max_minutes = 60

    @mock_aws
    def test_initialization(self):
        """Test AFIWaiter initialization."""
        waiter = AFIWaiter(self.afi_id, region=self.region, max_minutes=self.max_minutes)
        self.assertEqual(waiter.afi_id, self.afi_id)
        self.assertEqual(waiter.max_duration, timedelta(minutes=self.max_minutes))
        self.assertIsNotNone(waiter.ec2_client)

    @mock_aws
    def test_check_afi_status_available(self):
        """Test checking AFI status when available."""
        waiter = AFIWaiter(self.afi_id, region=self.region)

        waiter.ec2_client.describe_fpga_images = Mock(
            return_value={"FpgaImages": [{"State": {"Code": "available", "Message": "AFI is available"}}]}
        )

        status_code, error_message = waiter._check_afi_status()
        self.assertEqual(status_code, "available")
        self.assertIsNone(error_message)

    @mock_aws
    def test_check_afi_status_pending(self):
        """Test checking AFI status when pending."""
        waiter = AFIWaiter(self.afi_id, region=self.region)

        waiter.ec2_client.describe_fpga_images = Mock(
            return_value={
                "FpgaImages": [
                    {
                        "State": {
                            "Code": "pending",
                            "Message": "AFI generation in progress",
                        }
                    }
                ]
            }
        )

        status_code, error_message = waiter._check_afi_status()
        self.assertEqual(status_code, "pending")
        self.assertIsNone(error_message)

    @mock_aws
    def test_check_afi_status_failed(self):
        """Test checking AFI status when failed."""
        waiter = AFIWaiter(self.afi_id, region=self.region)

        error_msg = "DCP validation failed"
        waiter.ec2_client.describe_fpga_images = Mock(return_value={"FpgaImages": [{"State": {"Code": "failed", "Message": error_msg}}]})

        status_code, error_message = waiter._check_afi_status()
        self.assertEqual(status_code, "failed")
        self.assertEqual(error_message, error_msg)

    @mock_aws
    def test_check_afi_status_unavailable(self):
        """Test checking AFI status when unavailable."""
        waiter = AFIWaiter(self.afi_id, region=self.region)

        error_msg = "AFI unavailable"
        waiter.ec2_client.describe_fpga_images = Mock(
            return_value={"FpgaImages": [{"State": {"Code": "unavailable", "Message": error_msg}}]}
        )

        status_code, error_message = waiter._check_afi_status()
        self.assertEqual(status_code, "unavailable")
        self.assertEqual(error_message, error_msg)

    @mock_aws
    def test_check_afi_status_error(self):
        """Test checking AFI status when API call fails."""
        waiter = AFIWaiter(self.afi_id, region=self.region)

        waiter.ec2_client.describe_fpga_images = Mock(side_effect=Exception("API Error"))

        with self.assertRaises(Exception) as context:
            waiter._check_afi_status()
        self.assertIn("API Error", str(context.exception))

    @mock_aws
    @patch("time.sleep")
    def test_wait_for_completion_success(self, mock_sleep):
        """Test waiting for AFI completion - success case."""
        waiter = AFIWaiter(self.afi_id, region=self.region, max_minutes=10)

        # Simulate pending then available
        waiter.ec2_client.describe_fpga_images = Mock(
            side_effect=[
                {"FpgaImages": [{"State": {"Code": "pending"}}]},
                {"FpgaImages": [{"State": {"Code": "pending"}}]},
                {"FpgaImages": [{"State": {"Code": "available"}}]},
            ]
        )

        success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=1)

        self.assertTrue(success)
        self.assertEqual(status_code, "available")
        self.assertIsNone(error_message)
        self.assertEqual(mock_sleep.call_count, 2)

    @mock_aws
    @patch("time.sleep")
    def test_wait_for_completion_failed(self, mock_sleep):
        """Test waiting for AFI completion - failed case."""
        waiter = AFIWaiter(self.afi_id, region=self.region, max_minutes=10)

        error_msg = "Build failed"
        waiter.ec2_client.describe_fpga_images = Mock(
            side_effect=[
                {"FpgaImages": [{"State": {"Code": "pending"}}]},
                {"FpgaImages": [{"State": {"Code": "failed", "Message": error_msg}}]},
            ]
        )

        success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=1)

        self.assertFalse(success)
        self.assertEqual(status_code, "failed")
        self.assertEqual(error_message, error_msg)
        self.assertEqual(mock_sleep.call_count, 1)

    @mock_aws
    @patch("time.sleep")
    @patch("wait_for_afi.datetime")
    def test_wait_for_completion_timeout(self, mock_datetime, mock_sleep):
        """Test waiting for AFI completion - timeout case."""
        waiter = AFIWaiter(self.afi_id, region=self.region, max_minutes=1)

        # Mock datetime to simulate timeout
        start_time = datetime(2025, 1, 1, 0, 0, 0)
        timeout_time = start_time + timedelta(minutes=2)

        mock_datetime.utcnow.side_effect = [start_time, start_time, timeout_time]

        waiter.ec2_client.describe_fpga_images = Mock(return_value={"FpgaImages": [{"State": {"Code": "pending"}}]})

        success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=1)

        self.assertFalse(success)
        self.assertEqual(status_code, "timeout")
        self.assertEqual(error_message, "Maximum wait time exceeded")


class TestSNSFunctions(unittest.TestCase):
    """Test cases for SNS standalone functions."""

    def setUp(self):
        self.topic_name = "TEST_TOPIC"
        self.email = "test@example.com"
        self.region = "us-east-1"

    @mock_aws
    def test_setup_sns_notification_new_topic(self):
        """Test creating new SNS topic and subscribing email."""
        topic_arn = setup_sns_notification(self.email, self.topic_name, self.region)

        self.assertIsNotNone(topic_arn)
        self.assertIn(self.topic_name, topic_arn)

    @mock_aws
    def test_setup_sns_notification_existing_topic(self):
        """Test using existing SNS topic."""
        # Create topic first
        sns_client = boto3.client("sns", region_name=self.region)
        response = sns_client.create_topic(Name=self.topic_name)
        existing_arn = response["TopicArn"]

        topic_arn = setup_sns_notification(self.email, self.topic_name, self.region)

        self.assertEqual(topic_arn, existing_arn)

    @mock_aws
    def test_setup_sns_notification_pending_confirmation(self):
        """Test subscription pending confirmation."""
        with patch("boto3.client") as mock_boto_client:
            mock_sns = Mock()
            mock_boto_client.return_value = mock_sns
            mock_sns.create_topic.return_value = {"TopicArn": "arn:aws:sns:us-east-1:123:test"}
            mock_sns.subscribe.return_value = {"SubscriptionArn": "pending confirmation"}

            with patch("sys.stdout", new=StringIO()) as fake_out:
                topic_arn = setup_sns_notification(self.email, self.topic_name, self.region)
                output = fake_out.getvalue()
                self.assertIn("pending confirmation", output.lower())
                self.assertIsNotNone(topic_arn)

    @mock_aws
    def test_setup_sns_notification_error(self):
        """Test error handling during topic creation."""
        with patch("boto3.client") as mock_boto_client:
            mock_sns = Mock()
            mock_boto_client.return_value = mock_sns
            mock_sns.create_topic.side_effect = Exception("SNS Error")

            with self.assertRaises(Exception) as context:
                setup_sns_notification(self.email, self.topic_name, self.region)
            self.assertIn("SNS Error", str(context.exception))

    @mock_aws
    def test_send_sns_notification_success(self):
        """Test sending success notification."""
        topic_arn = setup_sns_notification(self.email, self.topic_name, self.region)
        afi_id = "afi-123"

        send_sns_notification(
            topic_arn,
            afi_id,
            success=True,
            status_code="available",
            region=self.region,
        )

    @mock_aws
    def test_send_sns_notification_failure(self):
        """Test sending failure notification."""
        topic_arn = setup_sns_notification(self.email, self.topic_name, self.region)
        afi_id = "afi-123"
        error_msg = "Build failed"

        # Should not raise exception
        send_sns_notification(topic_arn, afi_id, success=False, status_code="failed", error_message=error_msg, region=self.region)

    @mock_aws
    def test_send_sns_notification_error(self):
        """Test error handling during notification send."""
        topic_arn = "arn:aws:sns:us-east-1:123456789:test"

        with patch("boto3.client") as mock_boto_client:
            mock_sns = Mock()
            mock_boto_client.return_value = mock_sns
            mock_sns.publish.side_effect = Exception("Publish Error")

            with patch("sys.stdout", new=StringIO()):
                # Should not raise exception, just log error
                send_sns_notification(topic_arn, "afi-123", success=True, status_code="available", region=self.region)


class TestWaitForAFIFunction(unittest.TestCase):
    """Test cases for wait_for_afi function."""

    def setUp(self):
        self.afi_id = "afi-1234567890abcdef0"
        self.region = "us-east-1"
        self.email = "test@example.com"

    @mock_aws
    @patch("time.sleep")
    def test_wait_for_afi_success_no_notification(self, mock_sleep):
        """Test wait_for_afi function - success without notification."""
        with patch.object(AFIWaiter, "wait_for_completion") as mock_wait:
            mock_wait.return_value = (True, "available", None)

            exit_code = wait_for_afi(afi_id=self.afi_id, region=self.region)

            self.assertEqual(exit_code, 0)
            mock_wait.assert_called_once()

    @mock_aws
    @patch("time.sleep")
    def test_wait_for_afi_success_with_notification(self, mock_sleep):
        """Test wait_for_afi function - success with notification."""
        with (
            patch.object(AFIWaiter, "wait_for_completion") as mock_wait,
            patch("wait_for_afi.setup_sns_notification") as mock_sns_setup,
            patch("wait_for_afi.send_sns_notification") as mock_send,
        ):
            mock_wait.return_value = (True, "available", None)
            mock_sns_setup.return_value = "arn:aws:sns:us-east-1:123:test"

            exit_code = wait_for_afi(afi_id=self.afi_id, region=self.region, email=self.email)

            self.assertEqual(exit_code, 0)
            mock_sns_setup.assert_called_once()
            mock_send.assert_called_once()

    @mock_aws
    def test_wait_for_afi_failure(self):
        """Test wait_for_afi function - AFI generation failed."""
        with patch.object(AFIWaiter, "wait_for_completion") as mock_wait:
            mock_wait.return_value = (False, "failed", "Build error")

            exit_code = wait_for_afi(afi_id=self.afi_id, region=self.region)

            self.assertEqual(exit_code, 1)

    @mock_aws
    def test_wait_for_afi_sns_setup_error(self):
        """Test wait_for_afi function - SNS setup error."""
        with patch("wait_for_afi.setup_sns_notification") as mock_sns_setup:
            mock_sns_setup.side_effect = Exception("SNS Error")

            with self.assertRaises(Exception) as context:
                wait_for_afi(afi_id=self.afi_id, region=self.region, email=self.email)
            self.assertIn("SNS Error", str(context.exception))

    @mock_aws
    @patch("time.sleep")
    def test_wait_for_afi_custom_parameters(self, mock_sleep):
        """Test wait_for_afi function with custom parameters."""
        with patch.object(AFIWaiter, "wait_for_completion") as mock_wait:
            mock_wait.return_value = (True, "available", None)

            exit_code = wait_for_afi(afi_id=self.afi_id, region=self.region, max_minutes=120, sns_topic="CUSTOM_TOPIC", sleep_seconds=30)

            self.assertEqual(exit_code, 0)
            # Verify custom sleep_seconds was passed
            mock_wait.assert_called_once_with(sleep_seconds=30)


class TestMainFunction(unittest.TestCase):
    """Test cases for main CLI function."""

    def setUp(self):
        self.afi_id = "afi-1234567890abcdef0"

    @patch("sys.argv", ["wait_for_afi.py", "--afi", "afi-123"])
    @patch("wait_for_afi.wait_for_afi")
    def test_main_minimal_args(self, mock_wait):
        """Test main function with minimal arguments."""
        mock_wait.return_value = 0

        exit_code = main()

        self.assertEqual(exit_code, 0)
        mock_wait.assert_called_once()
        call_args = mock_wait.call_args[1]
        self.assertEqual(call_args["afi_id"], "afi-123")
        self.assertIsNone(call_args["email"])

    @patch("sys.argv", ["wait_for_afi.py", "--afi", "afi-123", "--email", "test@example.com"])
    @patch("wait_for_afi.wait_for_afi")
    def test_main_with_notification(self, mock_wait):
        """Test main function with notification parameters."""
        mock_wait.return_value = 0

        exit_code = main()

        self.assertEqual(exit_code, 0)
        call_args = mock_wait.call_args[1]
        self.assertEqual(call_args["email"], "test@example.com")

    @patch(
        "sys.argv",
        [
            "wait_for_afi.py",
            "--afi",
            "afi-123",
            "--max-minutes",
            "120",
            "--region",
            "us-west-2",
            "--sns-topic",
            "MY_TOPIC",
        ],
    )
    @patch("wait_for_afi.wait_for_afi")
    def test_main_with_custom_parameters(self, mock_wait):
        """Test main function with custom parameters."""
        mock_wait.return_value = 0

        exit_code = main()

        self.assertEqual(exit_code, 0)
        call_args = mock_wait.call_args[1]
        self.assertEqual(call_args["max_minutes"], 120)
        self.assertEqual(call_args["region"], "us-west-2")
        self.assertEqual(call_args["sns_topic"], "MY_TOPIC")

    @patch("sys.argv", ["wait_for_afi.py", "--afi", "afi-123"])
    @patch("wait_for_afi.wait_for_afi")
    def test_main_keyboard_interrupt(self, mock_wait):
        """Test main function handling keyboard interrupt."""
        mock_wait.side_effect = KeyboardInterrupt()

        exit_code = main()

        self.assertEqual(exit_code, 1)

    @patch("sys.argv", ["wait_for_afi.py", "--afi", "afi-123"])
    @patch("wait_for_afi.wait_for_afi")
    def test_main_exception(self, mock_wait):
        """Test main function handling generic exception."""
        mock_wait.side_effect = Exception("Test error")

        exit_code = main()

        self.assertEqual(exit_code, 1)

    @patch("sys.argv", ["wait_for_afi.py", "--help"])
    def test_main_help(self):
        """Test main function with help flag."""
        with self.assertRaises(SystemExit) as context:
            main()
        # Help should exit with 0
        self.assertEqual(context.exception.code, 0)

    @patch("sys.argv", ["wait_for_afi.py"])
    def test_main_missing_required_arg(self):
        """Test main function with missing required argument."""
        with patch("sys.stderr", new=StringIO()):
            with self.assertRaises(SystemExit) as context:
                main()
            # Missing required arg should exit with 2
            self.assertEqual(context.exception.code, 2)


class TestIntegration(unittest.TestCase):
    """Integration tests combining multiple components."""

    @mock_aws
    @patch("time.sleep")
    def test_end_to_end_success_with_notification(self, mock_sleep):
        """Test complete end-to-end flow with notification."""
        afi_id = "afi-1234567890abcdef0"
        email = "test@example.com"
        region = "us-east-1"

        # Create waiter
        waiter = AFIWaiter(afi_id, region=region, max_minutes=10)

        # Mock AFI becoming available after 2 checks
        waiter.ec2_client.describe_fpga_images = Mock(
            side_effect=[
                {"FpgaImages": [{"State": {"Code": "pending"}}]},
                {"FpgaImages": [{"State": {"Code": "available"}}]},
            ]
        )

        # Set up notification
        topic_arn = setup_sns_notification(email, DEFAULT_SNS_TOPIC, region)
        self.assertIsNotNone(topic_arn)

        # Wait for completion
        success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=1)
        self.assertTrue(success)
        self.assertEqual(status_code, "available")

        # Send notification
        send_sns_notification(topic_arn, afi_id, success, status_code, error_message, region)

        # Verify sleep was called
        self.assertEqual(mock_sleep.call_count, 1)

    @mock_aws
    @patch("time.sleep")
    def test_end_to_end_failure_with_notification(self, mock_sleep):
        """Test complete end-to-end flow with failure and notification."""
        afi_id = "afi-1234567890abcdef0"
        email = "test@example.com"
        region = "us-east-1"
        error_msg = "DCP validation failed"

        waiter = AFIWaiter(afi_id, region=region, max_minutes=10)

        # Mock AFI failing
        waiter.ec2_client.describe_fpga_images = Mock(return_value={"FpgaImages": [{"State": {"Code": "failed", "Message": error_msg}}]})

        topic_arn = setup_sns_notification(email, DEFAULT_SNS_TOPIC, region)
        success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=1)

        self.assertFalse(success)
        self.assertEqual(status_code, "failed")
        self.assertEqual(error_message, error_msg)

        send_sns_notification(topic_arn, afi_id, success, status_code, error_message, region)


if __name__ == "__main__":
    try:
        test_runner = unittest.TextTestRunner(buffer=True, verbosity=2)
        test_suite = unittest.TestLoader().loadTestsFromModule(__import__(__name__))
        result = test_runner.run(test_suite)
    except SystemExit:
        pass
    cov.stop()
    cov.save()
    cov.report(
        show_missing=True,
        skip_covered=True,  # Only show files that have missing lines
        skip_empty=True,  # Skip files with no executable statements
    )
    # Optional: Generate HTML report
    # cov.html_report()

    if not result.wasSuccessful():
        print("Unit tests failed!")
        sys.exit(1)
