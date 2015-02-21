# awscli scripts

to be run via guruvan/awscli docker image


in general these scripts will take env variables for AWS_ACCESS_KEY and AWS_SECRET_KEY
and put those into /root/.aws/credentials

If the scripts in here don't do that, building a new docker image with credentials is an option



```
docker run -it --rm \
 -v /some/dir/with/script:/app \
 -e AWS_ACCESS_KEY=[your key] \
 -e AWS_SECRET_KEY=[your_key] \
 guruvan/awscli /app/script.sh
```

30 hwy 20 city 
Your mileage may vary. 
