import { App, Stack, StackProps } from 'aws-cdk-lib';
import { RuntimeAmiBuilderStack } from './runtimeAmiBuilder';

export class MyInfrastructureStack extends Stack {
  constructor(scope: App, id: string, props?: StackProps) {
    super(scope, id, props);
    const amiBuilder = new RuntimeAmiBuilderStack(this, 'RuntimeAMIBuilder');
  }
}

const app = new App();

new MyInfrastructureStack(app, 'MyInfrastructureStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION
  }
});
