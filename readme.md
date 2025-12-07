## Struture
aws-img-pl/
  infrastructure/
    main.tf
    variables.tf
    outputs.tf
    s3.tf
    dynamodb.tf
    iam.tf
    lambda.tf
    stepfunctions.tf
    api_gateway.tf
  lambdas/
    trigger_step_function/
      handler.py
      requirements.txt
    resize_image/
      handler.py
      requirements.txt
    rekognition_labels/
      handler.py
      requirements.txt
    store_metadata/
      handler.py
      requirements.txt
  frontend/
    # Vue + Vite app
