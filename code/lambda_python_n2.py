import boto3
    
def lambda_handler(event, context):
    result = 'Success'
    return {
        'statusCode' : 200,
        'body': result
    }