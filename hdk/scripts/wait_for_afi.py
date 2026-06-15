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

"""
AFI Generation Waiter

Waits for AFI generation to complete and optionally sends email notifications.
Can be used standalone or imported as a module.
"""

import argparse
import sys
import time
import traceback
from datetime import datetime, timedelta

import boto3
from mypy_boto3_ec2.client import EC2Client
from mypy_boto3_sns.client import SNSClient

MAX_POLL_MINUTES = 360
DEFAULT_SNS_TOPIC = "CREATE_AFI"


class AFIWaiter:
    def __init__(self, afi_id: str, region: str | None = None, max_minutes: int = MAX_POLL_MINUTES):
        self.afi_id = afi_id
        self.max_duration = timedelta(minutes=max_minutes)
        self.ec2_client: EC2Client = boto3.client("ec2", region_name=region) if region else boto3.client("ec2")

    def _check_afi_status(self) -> tuple[str, str | None]:
        response = self.ec2_client.describe_fpga_images(FpgaImageIds=[self.afi_id])
        afi_info = response["FpgaImages"][0]
        state = afi_info["State"]
        status_code = state["Code"]
        error_message = state.get("Message") if status_code in ["failed", "unavailable"] else None
        return status_code, error_message

    def wait_for_completion(self, sleep_seconds: int) -> tuple[bool, str, str | None]:
        start_time = datetime.utcnow()
        print(f"⏳ Waiting for {self.afi_id} generation to complete...")
        print(f"⏱️  Maximum wait time: {self.max_duration.total_seconds() / 60:.1f} minutes")

        while True:
            status_code, error_message = self._check_afi_status()
            print(f"📊 Current status: {status_code}")

            if status_code == "available":
                print("🎉 AFI generation passed and AFI is available")
                return True, status_code, None

            if status_code in ["failed", "unavailable"]:
                print(f"❌ AFI generation failed. State={status_code} Message={error_message}")
                return False, status_code, error_message

            current_time = datetime.utcnow()
            elapsed = current_time - start_time
            if elapsed > self.max_duration:
                print("⏰ Timed out waiting for AFI generation to complete")
                return False, "timeout", "Maximum wait time exceeded"

            remaining = self.max_duration - elapsed
            print(
                f"⏳ Status: {status_code} | Elapsed: {elapsed.total_seconds() / 60:.1f}m | "
                f"Remaining: {remaining.total_seconds() / 60:.1f}m"
            )

            time.sleep(sleep_seconds)


def setup_sns_notification(email: str, topic_name: str, region: str | None = None) -> str:
    sns_client: SNSClient = boto3.client("sns", region_name=region) if region else boto3.client("sns")

    response = sns_client.create_topic(Name=topic_name)
    topic_arn = response["TopicArn"]
    print(f"📧 Using SNS topic: {topic_arn}")

    sub_response = sns_client.subscribe(TopicArn=topic_arn, Protocol="email", Endpoint=email, ReturnSubscriptionArn=True)

    subscription_arn = sub_response.get("SubscriptionArn")
    if subscription_arn == "pending confirmation":
        print(f"📬 Subscription pending confirmation. Check {email} for confirmation email")
    else:
        print(f"✅ Email {email} subscribed to topic {topic_name}")

    return topic_arn


def send_sns_notification(
    topic_arn: str,
    afi_id: str,
    success: bool,
    status_code: str,
    error_message: str | None = None,
    region: str | None = None,
):
    sns_client: SNSClient = boto3.client("sns", region_name=region) if region else boto3.client("sns")

    if success:
        subject = f"create-fpga-image of {afi_id} passed"
        message = f"🎉 AFI generation completed successfully!\nState={status_code}"
    else:
        subject = f"create-fpga-image of {afi_id} failed"
        message = f"❌ AFI generation failed!\nState={status_code}"
        if error_message:
            message += f"\nMessage={error_message}"

    try:
        sns_client.publish(TopicArn=topic_arn, Subject=subject, Message=message)
        print(f"📨 Notification sent: {subject}")
    except Exception as e:
        print(f"⚠️  Failed to send notification: {e}")


def wait_for_afi(
    afi_id: str,
    region: str | None = None,
    max_minutes: int = MAX_POLL_MINUTES,
    email: str | None = None,
    sns_topic: str = DEFAULT_SNS_TOPIC,
    sleep_seconds: int = 60,
) -> int:
    topic_arn = None
    if email:
        topic_arn = setup_sns_notification(email, sns_topic, region)

    waiter = AFIWaiter(afi_id=afi_id, region=region, max_minutes=max_minutes)
    success, status_code, error_message = waiter.wait_for_completion(sleep_seconds=sleep_seconds)

    if topic_arn:
        send_sns_notification(topic_arn, afi_id, success, status_code, error_message, region)

    return 0 if success else 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Wait for AFI generation to complete and optionally send email notification.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Wait for AFI without notification
  wait_for_afi.py --afi afi-1234567890abcdef0

  # Wait and send email notification
  wait_for_afi.py --afi afi-1234567890abcdef0 --email user@example.com

  # Custom timeout and SNS topic
  wait_for_afi.py --afi afi-1234567890abcdef0 --max-minutes 120 \\
                  --email user@example.com --sns-topic MY_TOPIC
        """,
    )

    parser.add_argument("--afi", required=True, help="AFI ID (not Global AFI ID)")
    parser.add_argument(
        "--max-minutes",
        type=int,
        default=MAX_POLL_MINUTES,
        help=f"Maximum minutes to wait (default: {MAX_POLL_MINUTES})",
    )
    parser.add_argument("--email", help="Email address for notification (sends email when AFI generation completes)")
    parser.add_argument("--sns-topic", default=DEFAULT_SNS_TOPIC, help=f"SNS topic name (default: {DEFAULT_SNS_TOPIC})")
    parser.add_argument("--region", help="AWS region (defaults to session default)")

    args = parser.parse_args()

    try:
        return wait_for_afi(
            afi_id=args.afi,
            region=args.region,
            max_minutes=args.max_minutes,
            email=args.email,
            sns_topic=args.sns_topic,
        )
    except KeyboardInterrupt:
        print("\n⚠️  Operation cancelled by user", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
