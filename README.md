# Containerized Python API, Kafka, AWS Lambda Consumer

Hello! This is a high-quality containerized **Python API &rarr; managed Kafka
cluster &rarr; AWS Lambda consumer function** reference architecture,
provisioned with Terraform. (CloudFormation is used indirectly, for a modular
Kafka consumer stack.) I hope you will be able to adapt it for your own
projects, under the terms of the license.

## Innovations and Best Practices

- Small image
- Secure container
- Secure private network
- Low-code
- Low-cost
- Ready for continuous-integration/continuous-deployment

<details>
  <summary>Table of innovations and best practices...</summary>

<br/>

|<br/>&check; Quality|~Typical&nbsp;approach~<br/>My&nbsp;work|<br/>Advantage|
|:---|:---|:---|
|<br/>**&check; Small image**|||
|Package and module caches|~Cleared or disabled~<br/>[Docker&nbsp;cache&nbsp;mounts](https://docs.docker.com/build/cache/optimize/#use-cache-mounts)|No bloat, _and_ no slow re-downloading on image re-build|
|Temporary Python modules|~Retained~<br/>Uninstalled|Same discipline as for operating system packages|
|Temporary software installation, usage, and removal|~Separate&nbsp;layers; maybe&nbsp;stages?~<br/>Same&nbsp;layer|Fewer, smaller layers, _without_ [multi&#8209;stage&nbsp;build](https://docs.docker.com/build/building/multi-stage#use-multi-stage-builds) complexity|
|<br/>**&check; Secure container**|||
|Base image|~Docker&nbsp;Community&nbsp;Python~<br/>Amazon&nbsp;Linux|Fewer vulnerabilities; frequent updates, _from AWS staff_; [deterministic&nbsp;OS&nbsp;package&nbsp;versions](https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades.html)|
|Image build platform|~Local computer~<br/>[AWS&nbsp;CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)&nbsp;or&nbsp;EC2|Controlled, auditable environment; low malware risk|
|Non-root user|~Maybe?~<br/>Yes|Less access if main process is compromised|
|<br/>**&check; Secure private network**|||
|Internet from private subnets|~NAT&nbsp;Gateway~<br/>No|Lower data exfiltration risk|
|AWS service endpoints|~Public~<br/>Private|Traffic never leaves private network|
|Security group rule scope|~Ranges&nbsp;of&nbsp;numbered&nbsp;addresses~<br/>Other&nbsp;named&nbsp;security&nbsp;groups|Only known pairs of resources can communicate|
|<br/>**&check; Low-code**|||
|API specification|~In program code~<br/>[OpenAPI document](https://learn.openapis.org/introduction.html#api-description-using-the-oas)|Standard and self-documenting; declarative input validation|
|Serverless compute|~No~<br/>ECS&nbsp;Fargate|Fewer, simpler resource definitions; no platform-level patching|
|Serverless Kafka consumer|~No~<br/>AWS&nbsp;Lambda|[AWS&nbsp;event&nbsp;source&nbsp;mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-msk-configure.html#msk-esm-overview) handles Kafka; code receives JSON input (I re-used an SQS consumer CloudFormation template from my other projects!)|
|<br/>**&check; Low-cost**|||
|Compute pricing|~On-demand; maybe&nbsp;Savings&nbsp;Plan?~<br/>Spot&nbsp;discount|No commitment; [_EC2_&nbsp;Spot&nbsp;discounts](https://aws.amazon.com/ec2/spot/instance-advisor) are higher than [Savings&nbsp;Plan&nbsp;discounts](https://aws.amazon.com/savingsplans/compute-pricing) and [_Fargate_&nbsp;Spot&nbsp;pricing](https://aws.amazon.com/fargate/pricing#Fargate_Spot_Pricing_for_Amazon_ECS) works similarly|
|CPU architecture|~Intel&nbsp;x86~<br/>ARM&nbsp;(AWS&nbsp;Graviton)|[Better&nbsp;price/performance&nbsp;ratio](https://aws.amazon.com/ec2/graviton); same [CPU&nbsp;off&#8209;load](https://aws.amazon.com/ec2/nitro)|
|Expensive resources|~Always&nbsp;on~<br/>Conditional|Develop and test at the lowest AWS cost|
|<br/>**&check; CI/CD-ready**|||
|Image build properties|~Hard-coded~<br/>Terraform&nbsp;variables|Multiple versions can coexist, for testing and blue/green deployment|
|Image build software platform|~MacOS~<br/>Amazon&nbsp;Linux|Ready for centralized building|
|Private address allocation|~Fixed~<br/>Flexible|Specify one address space for [AWS&nbsp;IP&nbsp;Address&nbsp;Manager&nbsp;(IPAM)](https://docs.aws.amazon.com/vpc/latest/ipam/what-it-is-ipam.html) to divide|
|Lambda function tests|~In&nbsp;files~<br/>[Central,&nbsp;shared&nbsp;registry](https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events)|[Realistic, centrally&#8209;executed&nbsp;tests](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/using-sam-cli-remote-invoke.html#using-sam-cli-remote-invoke-shareable) (see [shareable&nbsp;Lambda&nbsp;test](https://github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/blob/1edaa6a/cloudformation/kafka_consumer.yaml#L567-L598))|

</details>

Jump to:
[Recommendations](#recommendations)
&bull;
[Licenses](#licenses)

## Installation

 1. Choose between
    [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
    or an EC2 instance for building the Docker image and running Terraform.

    - **CloudShell**<br/>_Easy_ &check;

      - Authenticate to the AWS Console. Use a non-production AWS account and
        a privileged role.

      - Open an
        [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)
        terminal.

      - Prepare for a cross-platform container image build. CloudShell seems to
        provide Intel CPUs. The following instructions are from
        "[Multi-platform builds](https://docs.docker.com/build/building/multi-platform/#prerequisites)"
        in the Docker Build manual.

        ```shell
        sudo docker buildx create --name 'container-builder' --driver 'docker-container' --bootstrap --use

        ```

        ```shell
        sudo docker run --privileged --rm 'tonistiigi/binfmt' --install all

        ```

      - Review the
        [Terraform S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3)
        and
        [create an S3 bucket](https://console.aws.amazon.com/s3/bucket/create?bucketType=general)
        to store Terraform state.

      - If at any time you find that your previous CloudShell session has
        expired, repeat any necessary software installation steps. Your home
        directory is preserved between sessions, subject to
        [CloudShell persistent storage limitations](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html#persistent-storage-limitations).

    - **EC2 instance**

      <details>
        <summary>EC2 instructions...</summary>

      <br/>

      - Create and/or connect to an EC2 instance. I recommend:

        - `arm64`
        - `t4g.micro` &#9888; The ARM-based AWS Graviton `g` architecture
          avoids multi-platform build complexity.
        - Amazon Linux 2023
        - A 30&nbsp;GiB EBS volume, with default encryption (supports
          hibernation)
        - No key pair; connect through
          [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
        - A custom security group with no ingress rules (yay for Session
          Manager!)
        - A `sched-stop` = `d=_ H:M=07:00` tag for automatic nightly
          shutdown (this example corresponds to midnight Pacific Daylight Time)
          with
          [sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#quick-start)

      - During the instance creation workflow (Advanced details &rarr; IAM
        instance profile &rarr; Create new IAM profile) or afterward, give
        your EC2 instance a custom role. Terraform must be able to
        list/describe, get tags for, create, tag, untag, update, and delete all
        of the AWS resource types included in this project's `.tf` files.

      - Update operating system packages (thanks to AWS's
        [deterministic upgrade philosophy](https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades.html),
        there shouldn't be any updates if you chose the latest Amazon Linux
        2023 image), install Docker, and start it.

        ```shell
        sudo dnf check-update
        ```

        ```shell
        sudo dnf --releasever=latest update
        ```

        ```shell
        sudo dnf install docker
        ```

        ```shell
        sudo systemctl start docker
        ```

      </details>

 2. Install Terraform. I'm standardizing on
    [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
    as the minimum supported version for my open-source projects.

    ```shell
    sudo dnf --assumeyes install 'dnf-command(config-manager)'

    ```

    ```shell
    sudo dnf config-manager --add-repo 'https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo'
    # sudo dnf --assumeyes install terraform-1.10.0-1
    sudo dnf --assumeyes install terraform

    ```

 3. Clone this repository and create `terraform.tfvars` to customize variables.

    ```shell
    git clone 'https://github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws.git' ~/docker-python-openapi-kafka
    cd ~/docker-python-openapi-kafka/terraform
    touch terraform.tfvars

    ```

    <details>
      <summary>Generate a terraform.tfvars skeleton...</summary>

    <br/>

    ```shell
    # Requires an up-to-date GNU sed (not the MacOS default!)
    sed --regexp-extended --silent  \
        --expression='s/^variable "(.+)" \{$/\n\n# \1 =/p' \
        --expression='s/^  description = "(.+)"$/#\n# \1/p' \
        --expression='s/^  default = (.+)$/#\n# Default: \1/p' variables.tf

    ```

    </details>

    _Optional:_ To save money while building the Docker container image, set
    `hello_api_aws_ecs_service_desired_count_tasks = 0` and
    `create_vpc_endpoints_and_load_balancer = false`&nbsp;.

 4. In CloudShell (optional if you chose EC2), create an override file to
    configure your Terraform S3 backend.

    ```shell
    cat > terraform_override.tf << 'EOF'
    terraform {
      backend "s3" {
        insecure = false

        region = "RegionCodeForYourS3Bucket"
        bucket = "NameOfYourS3Bucket"
        key    = "DesiredTerraformStateFileName"

        use_lockfile = true # No more DynamoDB; now S3-native!
      }
    }
    EOF

    ```

 5. Initialize Terraform and create the AWS infrastructure. There's no need for
    a separate `terraform plan` step. `terraform apply` outputs the plan and
    gives you a chance to approve before anything is done. If you don't like
    the plan, don't type `yes`&nbsp;!

    ```shell
    terraform init

    ```

    ```shell
    terraform apply -target='aws_vpc_ipam_pool_cidr_allocation.hello_vpc_private_subnets' -target='aws_vpc_ipam_pool_cidr_allocation.hello_vpc_public_subnets'

    ```

    <details>
      <summary>About this two-stage process...</summary>

    <br/>

    CloudPosse's otherwise excellent
    [dynamic-subnets](https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest)
    module isn't dynamic enough to co-operate with
    [AWS&nbsp;IP&nbsp;Address&nbsp;Manager&nbsp;(IPAM)](https://docs.aws.amazon.com/vpc/latest/ipam/what-it-is-ipam.html),
    so you have to let IPAM finalize subnet IP address range allocations
    beforehand.

    </details>

    ```shell
    terraform apply

    ```

    <details>
      <summary>In case of an "already exists" error...</summary>

    <br/>

    - If you receive a "Registry with name `lambda-testevent-schemas` already
      exists" error, set
      `create_lambda_testevent_schema_registry = false`&nbsp;, then run
      `terraform apply` again.

    </details>

 6. Set environment variables needed for building, tagging and pushing up the
    Docker container image, then build it.

    ```shell
    AMAZON_LINUX_BASE_VERSION=$(terraform output -raw 'amazon_linux_base_version')
    AMAZON_LINUX_BASE_DIGEST=$(terraform output -raw 'amazon_linux_base_digest')
    AWS_ECR_REGISTRY_REGION=$(terraform output -raw 'hello_api_aws_ecr_registry_region')
    AWS_ECR_REGISTRY_URI=$(terraform output -raw 'hello_api_aws_ecr_registry_uri')
    AWS_ECR_REPOSITORY_URL=$(terraform output -raw 'hello_api_aws_ecr_repository_url')
    HELLO_API_AWS_ECR_IMAGE_TAG=$(terraform output -raw 'hello_api_aws_ecr_image_tag')

    aws ecr get-login-password --region "${AWS_ECR_REGISTRY_REGION}" | sudo docker login --username 'AWS' --password-stdin "${AWS_ECR_REGISTRY_URI}"

    cd ../python_docker

    ```

    ```shell
    sudo docker buildx build --build-arg AMAZON_LINUX_BASE_VERSION="${AMAZON_LINUX_BASE_VERSION}" --build-arg AMAZON_LINUX_BASE_DIGEST="${AMAZON_LINUX_BASE_DIGEST}" --platform='linux/arm64' --tag "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}" --output 'type=docker' .

    ```

    ```shell
    sudo docker push "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}"

    ```

    <details>
      <summary>Updating the container image...</summary>

    <br/>

    - You can select a newer Amazon Linux release by setting the
      `amazon_linux_base_version` and `amazon_linux_base_digest` variables in
      Terraform, running `terraform apply`&nbsp;, and re-setting the
      environment variables.

      Then, to re-build the image, run `HELLO_API_AWS_ECR_IMAGE_TAG='1.0.1'`
      (choose an appropriate new version number, taking
      [semantic&nbsp;versioning](https://semver.org/#semantic-versioning-specification-semver)
      into account) in the shell, repeat the build and push commands, set
      `hello_api_aws_ecr_image_tag = "1.0.1"` (for example) in Terraform, and
      run `terraform apply` one more time.

    </details>

 7. _If_ you changed Terraform variables at the end of Step&nbsp;3, revert the
    changes and run `terraform apply`&nbsp;.

 8. In the Amazon Elastic Container Service section of the AWS Console, check
    the `hello_api` cluster. Eventually, you should see 2&nbsp;tasks running.

    - It will take a few minutes for ECS to notice, and then deploy, the
      container image. Relax, and let it happen. If you are impatient, or if
      there is a problem, you can navigate to the `hello_api` service, open the
      orange "Update service" pop-up menu, and select "Force new deployment".

 9. Generate the URLs and then test your API.

    ```shell
    cd ../terraform
    HELLO_API_DOMAIN_NAME=$(terraform output -raw 'hello_api_load_balander_domain_name') # For later
    echo -e "curl --location --insecure 'http://${HELLO_API_DOMAIN_NAME}/"{'healthcheck','hello','current_time?name=Paul','current_time?name=;echo','error'}"'\n"

    ```

    Try the different URLs using your Web browser or
    `curl --location --insecure`
    (these options allow redirection and self-signed TLS certificates).

    |Method, parameters|Result expected|
    |:---|:---|
    |`/healthcheck`|Empty response|
    |`/hello`|Fixed greeting, in a JSON object|
    |`/current_time?name=Paul`|Reflected greeting and timestamp, in a JSON object|
    |`/current_time?name=;echo`|HTTP `400` "bad request" error;<br/>Demonstrates protection from command injection|
    |`/error`|HTTP `404` "not found" error|

    <details>
      <summary>About redirection to HTTPS, and certificates...</summary>

    <br/>

    Your Web browser should redirect you from `http:` to `https:` and (let's
    hope!) warn you about the untrusted, self-signed TLS certificate used in
    this system (which of course is not tied to a pre-determined domain name).
    Proceed to view the responses from your new API...

    If your browser configuration does not allow accessing Web sites with
    untrusted certificates, change the `enable_https` variable to `false` and
    run `terraform apply`&nbsp;. Now, `http:` links will work without
    redirection. After you have used `https:` with a particular domain, your
    browser might no longer allow `http:`&nbsp;. Try with another browser.

    </details>

10. Access the
    [`/hello/hello_api_web_log`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/$252Fhello$252Fhello_api_web_log)
    CloudWatch log group in the AWS Console.

    Periodic internal health checks, plus your occasional Web requests, should
    appear.

    <details>
      <summary>API access log limitations...</summary>

    <br/>

    The Python
    [connexion](https://connexion.readthedocs.io/en/stable)
    module, which I chose because it serves an API from a precise
    [OpenAPI-format specification](https://learn.openapis.org/introduction.html#api-description-using-the-oas),
    uses
    [uvicorn](https://uvicorn.dev)
    workers. Unfortunately,
    [uvicorn has lousy log format customization support](https://github.com/Kludex/uvicorn/issues/527).

    </details>

11. If you wish to run commands remotely, or to open an interactive shell
    inside a `hello_api` container, use
    [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html).

    <details>
      <summary>ECS Exec instructions...</summary>

    <br/>

    Change the `enable_ecs_exec` variable to `true`&nbsp;, run
    `terraform apply`&nbsp;, and replace the container(s) using "Force new
    deployment", as explained at the end of Step&nbsp;8.

    In the Amazon Elastic Container Service section of the AWS Console, click
    `hello_api` to open the cluster's page. Open the "Tasks" tab and click an
    identifier in the "Task" column. Under "Containers", select the container,
    then click "Connect". Confirm the command that will be executed.

    You can also use the AWS command-line interface from your main CloudShell
    session (or, with sufficient permissions, from an EC2 instance if you chose
    to deploy from EC2).

    ```shell
    aws ecs list-tasks --cluster 'hello_api' --query 'taskArns' --output text
    read -p 'Task ID: ' HELLO_API_ECS_TASK_ID
    aws ecs execute-command --cluster 'hello_api' --task "${HELLO_API_ECS_TASK_ID}" --interactive --command '/bin/bash'
    ```

    Activities are logged in the
    [`/hello/hello_api_ecs_exec_log`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/$252Fhello$252Fhello_api_ecs_exec_log)
    CloudWatch log group.

    </details>

12. If you don't wish use Kafka, skip to Step&nbsp;14.

    If you wish to enable Kafka, set `enable_kafka = true`&nbsp; and run
    `terraform apply`&nbsp;. AWS MSK is expensive, so enable Kafka only after
    confirming that the rest of the system is working for you.

    <details>
      <summary>In case HelloApiKafkaConsumer CloudFormation stack creation fails...</summary>

    <br/>

    Creation of the Kafka consumer might fail for various reasons. Once the
    `HelloApiKafkaConsumer` CloudFormation stack is in `ROLLBACK_COMPLETE`
    status, delete it, then run `terraform apply` again.

    </details>

13. Access the `/current_time?name=Paul` method several times (adjust the name
    parameter as you wish). The first use of this method prompts creation of
    the `events` Kafka topic. From now on, use of this method (not the others)
    will send a message to the `events` Kafka topic.

    The [AWS MSK event source mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-msk-configure.html#msk-esm-overview)
    reads from the Kafka topic and triggers the consumer Lambda function, which
    logs decoded Kafka messages to the
    [HelloApiKafkaConsumer](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3DHelloApiKafkaConsumer-LambdaFnLogGrp-)
    CloudWatch log group.

14. If you wish to continue experimenting, set the `enable_kafka`&nbsp;,
    `hello_api_aws_ecs_service_desired_count_tasks` and
    `create_vpc_endpoints_and_load_balancer` variables to their cost-saving
    values and run `terraform apply`&nbsp;.

    When you are finished, delete all resources; the minimum configuration
    carries a cost.

    If you will be using the container image again soon, you can preserve the
    Elastic Container Registry image repository (at a cost) by removing it from
    Terraform state.

    ```shell
    cd ../terraform
    terraform state rm 'aws_schemas_registry.lambda_testevent'
    # terraform state rm 'aws_ecr_repository.hello' 'aws_ecr_lifecycle_policy.hello' 'data.aws_ecr_lifecycle_policy_document.hello'
    terraform apply -destroy
    ```

    <details>
      <summary>Deletion delays and errors...</summary>

    <br/>

    - Harmless "Invalid target address" errors may occur in some
      configurations.

    - Deleting a VPC Lambda function takes a long time because of the network
      association; expect 30&nbsp;minutes if `enable_kafka` was `true`&nbsp;.

    - Expect an error message about retiring KMS encryption key grants
      (harmless, in this case).

    - If you cancel and re-run `terraform apply -destroy`&nbsp;, a bug in
      CloudPosse's `dynamic-subnets` module might cause a "value depends on
      resource attributes that cannot be determined until apply" error. For a
      work-around, edit the cached module file indicated in the error message.
      Comment out the indicated line and force `count = 0`&nbsp;. Be sure to
      revert this temporary patch later.

    </details>

## Comments

### Artificial Intelligence and Large Language Models (LLMs)

This is my own original work, produced _without_ the use of artificial
intelligence (AI) and large language model (LLM) code generation. Code from
other sources is acknowledged.

### Long Option Names

I write long option names in my instructions so that other people don't have to
look up unfamiliar single-letter options &mdash; assuming they can _find_ them!

Here's an example that shows why I go to the trouble, even at the expense of
being laughed at by macho Linux users. I started using
[UNICOS](https://en.wikipedia.org/wiki/UNICOS)
in 1991, so it's not for lack of experience.

> Search for the literal text `-t` in
[docs.docker.com/reference/cli/docker/buildx/build](https://docs.docker.com/reference/cli/docker/buildx/build/)&nbsp;,
using Command-F, Control-F, `/`&nbsp;, or `grep`&nbsp;. Only
2&nbsp;of&nbsp;41&nbsp;occurrences of `-t` are relevant!

Where available, full-text (that is, not strictly literal) search engines
can't make sense of a 1-letter search term and are also likely to ignore a
2-character term as a "stop-word" that's too short to search for.

### Recommendations

My professional and ethical commitment is simple: Only as much technology as a
business...

- needs,
- can afford,
- understands (or can learn), and
- can maintain.

Having worked for startups since 2013, I always recommend focusing software
engineering effort. It is not possible to do everything, let alone to be good
at everything. Managed services, serverless technology, and low-code
architecture free software engineers to _focus on the core product, that is, on
what the company actually sells_. Avoid complex infrastructure and tooling
unless it offers a unique, tangible, and substantial benefit. Simplicity pays!

Security is easier and cheaper to incorporate at the start than to graft on
after the architecture has been finalized, the infrastructure has been
templated and created, and the executable code has been written and deployed.

Specialized knowledge of the chosen cloud provider is indispensable. I call it
"idiomatic" knowledge, a good part of which is awareness of the _range of
options_ supported by your cloud provider. Building generically would mean
giving up some performance, some security, and some cloud cost savings.
Optimizing later is difficult. "Lean to steer the ship you're on."

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE_CODE.md](/LICENSE_CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE_DOC.md](/LICENSE_DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
