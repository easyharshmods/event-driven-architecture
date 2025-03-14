# data.tf - Consolidated data sources

# Get current AWS region
data "aws_region" "current" {}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get the user credentials after they've been created
data "aws_secretsmanager_secret_version" "user_credentials" {
  secret_id  = aws_secretsmanager_secret.user_credentials.id
  depends_on = [null_resource.create_user]
}

# Create a zip file for the create user Lambda function
data "archive_file" "create_user_lambda" {
  type        = "zip"
  output_path = "${path.module}/files/create_user_lambda.zip"

  source {
    content  = <<EOF
import logging
import json
import cfnresponse
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

cognitoIdp = boto3.client('cognito-idp')
secretsmanager = boto3.client('secretsmanager')

def lambda_handler(event, context):
  logger.info('{}'.format(event))
  responseData = {}

  try:
    if event['RequestType'] == 'Create':
      userPoolId = event['ResourceProperties'].get('UserPoolId')
      clientId = event['ResourceProperties'].get('ClientId')
      secretId = event['ResourceProperties'].get('SecretId')

      response = secretsmanager.get_secret_value(
        SecretId=secretId
      )

      secretString=json.loads(response['SecretString'])

      response = cognitoIdp.sign_up(
        ClientId=clientId,
        Username=secretString['username'],
        Password=secretString['password']
      )

      response = cognitoIdp.admin_confirm_sign_up(
        UserPoolId=userPoolId,
        Username=secretString['username']
      )

      responseData['username'] = secretString['username']
      responseData['password'] = secretString['password']

    else: # delete / update
      rs = event['PhysicalResourceId']

    logger.info('responseData {}'.format(responseData))
    cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
  except:
    logger.error("custom resource failed", exc_info=True)
    cfnresponse.send(event, context, cfnresponse.FAILED, responseData)
EOF
    filename = "index.py"
  }

  source {
    content  = <<EOF
import json
import logging
import urllib.request

SUCCESS = "SUCCESS"
FAILED = "FAILED"

def send(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False):
    responseUrl = event['ResponseURL']

    print(responseUrl)

    responseBody = {}
    responseBody['Status'] = responseStatus
    responseBody['Reason'] = 'See the details in CloudWatch Log Stream: ' + context.log_stream_name
    responseBody['PhysicalResourceId'] = physicalResourceId or context.log_stream_name
    responseBody['StackId'] = event['StackId']
    responseBody['RequestId'] = event['RequestId']
    responseBody['LogicalResourceId'] = event['LogicalResourceId']
    responseBody['NoEcho'] = noEcho
    responseBody['Data'] = responseData

    json_responseBody = json.dumps(responseBody)

    print("Response body:\n" + json_responseBody)

    headers = {
        'content-type' : '',
        'content-length' : str(len(json_responseBody))
    }

    try:
        req = urllib.request.Request(responseUrl,
                                     json_responseBody.encode('utf-8'),
                                     headers)
        response = urllib.request.urlopen(req)
        print("Status code: " + response.reason)
    except Exception as e:
        print("send(..) failed executing requests.put(..): " + str(e))
EOF
    filename = "cfnresponse.py"
  }
}

# Create a zip file for the inventory Lambda function
data "archive_file" "inventory_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/files/inventory_lambda.zip"

  source {
    content  = <<EOF
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

FORCE_ERROR_ATTRIBUTE_KEY = 'force-error'

def lambda_handler(event, context):
  logger.info('{}'.format(event))
  event_detail = event['detail']
  order_detail = event_detail['OrderDetails']

  if (FORCE_ERROR_ATTRIBUTE_KEY in order_detail and order_detail[FORCE_ERROR_ATTRIBUTE_KEY]):
    error_message = 'FAILED! (force-error == true)'
    logger.error(error_message)
    raise Exception(error_message)

  return event_detail
EOF
    filename = "index.py"
  }
}

# Create a zip file for the dodgy Lambda function
data "archive_file" "dodgy_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/files/dodgy_lambda.zip"

  source {
    content  = <<EOF
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
  logger.info('{}'.format(event))
  return event
EOF
    filename = "index.py"
  }
}

# Create a zip file for the custom authorizer Lambda function
data "archive_file" "authorizer_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/files/authorizer_lambda.zip"

  source {
    content  = <<EOF
exports.handler = async (event) => {
  console.log(JSON.stringify(event));

  let authorizedUsername = '${var.api_auth_username}';
  let authorizedPassword = '${var.api_auth_password}';

  let authorization = event.headers.Authorization
  if (!authorization) {
    return policyDocument('Deny', 'unauthorized', event);
  }

  let credentials = authorization.split(' ')[1]
  let [username, password] = (Buffer.from(credentials, 'base64')).toString().split(':')
  if (!(username === authorizedUsername && password === authorizedPassword)) {
    return policyDocument('Deny', username, event);
  }

  return policyDocument('Allow', username, event);
};

function policyDocument(effect, username, event) {
  let methodArn = event.methodArn.split(':');
  let apiGatewayArn = methodArn[5].split('/');
  let accountId = methodArn[4];
  let region = methodArn[3];
  let restApiId = apiGatewayArn[0];
  let stage = apiGatewayArn[1];

  return {
    principalId: username,
    policyDocument: {
      Version: '2012-10-17',
      Statement: [
        {
          Action: 'execute-api:Invoke',
          Effect: effect,
          Resource: "arn:aws:execute-api:" + region + ":" + accountId + ":" + restApiId + "/" + stage + "/*/*"
        }
      ]
    }
  };
};
EOF
    filename = "index.js"
  }
}

# Local values based on data sources
locals {
  user_credentials = jsondecode(data.aws_secretsmanager_secret_version.user_credentials.secret_string)
  account_id       = data.aws_caller_identity.current.account_id
  region           = data.aws_region.current.name
}