FROM public.ecr.aws/lambda/python:3.12

# Copy all the files in a folder
COPY . ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip install -r requirements.txt

# Set the CMD to the lambda_handler
CMD [ "handler.lambda_handler" ]
