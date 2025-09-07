# Containerized API, Kafka Cluster, Lambda Consumer

_Containerized REST API &rarr; managed Kafka cluster &rarr; Lambda consumer,
on AWS, provisioned via Terraform (demonstration only)_

Jump to:
[Get Started](#get-started)
&bull;
[Commentary](#commentary)

## Diagram

Intentionally omitted. See [Limitations](#limitations).

## Get Started

Forthcoming...

## Commentary

I developed this in September,&nbsp;2025, in response to a take-home technical
exercise for a Senior DevOps Engineer position with a medium-sized US East
Coast startup.

### Statement on AI, LLMs and Code Generation

This is my own work, produced _without_ the use of artificial intelligence /
large language model code generation.

### Limitations

This is a comprehensive, working solution, though as a demonstration project,
it is not intended for production use.

Producing this realistic solution required significant free labor. To limit
free labor, I:

- **Omitted the architecture diagram.** Diagrams generated automatically from
  infrastructure-as-code templates might look pretty but their explanatory
  power is low. The level of detail always seems too high or too low for the
  audience. For example,
  [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)
  resources will be drawn with arrows between a role and multiple _AWS-managed_
  policies, when the role and a list of the policy names could just be enclosed
  in a box, because the names are thoroughly descriptive. Schooled decades ago
  by Dr. Edward Tufte's
  [_The Visual Display of Quantitative Information_](https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information),
  I have produced compact, attractive, information-rich diagrams for my
  pre-existing open-source projects. They address multiple audiences and were
  easy to draw using Apple's free "Freeform" application. Examples:
  <br/>
  <br/>
  [<img src="https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow-thumb.png" alt="An Event Bridge Scheduler rule triggers the 'Find' Amazon Web Services Lambda function every 10 minutes. The function calls 'describe' methods, checks the resource records returned for tag keys such as 'sched-start', and uses regular expressions to check the tag values for day, hour, and minute terms. Current day and time elements are inserted into the regular expressions using 'strftime'. If there is a match, the function sends a message to a Simple Queue Service queue. The 'Do' function, triggered in response, checks whether the message has expired. If not, this function calls the method indicated by the message attributes, passing the message body for the parameters. If the request is successful or a known exception occurs and it is not okay to re-try, the function is done. If an unknown exception occurs, the message remains in the operation queue, becoming visibile again after 90 seconds. After 3 tries, a message goes from the operation queue to the error (dead letter) queue." height="144" />](https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Lights Off, AWS!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png" alt="After waiting 9 minutes, call to stop the Relational Database Service or Aurora database. Case 1: If the stop request succeeds, retry. Case 2: If the Aurora cluster is in an invalid state, parse the error message to get the status. Case 3: If the RDS instance is in an invalid state, get the status by calling to describe the RDS instance. Exit if the database status from Case 2 or 3 is 'stopped' or another final status. Otherwise, retry every 9 minutes, for 24 hours." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png?raw=true "Simplified flowchart for [Step-]Stay Stopped, RDS and Aurora!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow-thumb.png" alt="Relational Database Service Event Bridge events '0153' and '0154' (database started after exceeding 7-day maximum stop time) go to the main Simple Queue Service queue, where messages are initially delayed 9 minutes. The Amazon Web Services Lambda function stops the RDS instance or the Aurora cluster. If the database's status is invalid, the queue message becomes visible again in 9 minutes. A final status of 'stopping', 'deleting' or 'deleted' ends retries, as does an error status. After 160 tries (24 hours), the message goes to the error (dead letter) SQS queue." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Stay Stopped, RDS and Aurora!")

- **Used AWS-managed Identity and Access Management (IAM) policies** rather than
  write my trademark custom least-privilege policies. My long-standing
  open-source projects model least-privilege IAM policies. See, for example,
  the
  [CloudFormation deployment role](https://github.com/sqlxpert/lights-off-aws/blob/fe1b565/cloudformation/lights_off_aws_prereq.yaml#L83-L267)
  and the
  [Lambda function roles](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L484-L741)
  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.

- **Did not implement encryption in all places, or encryption with
  customer-managed KMS keys.** My pre-existing projects model comprehensive
  encryption support, including support for custom KMS keys, keys housed in a
  dedicated AWS account, and multi-region keys. See, for example,
  [`SqsKmsKey`](https://github.com/sqlxpert/step-stay-stopped-aws-rds-aurora/blob/2da11e1/step_stay_stopped_aws_rds_aurora.yaml#L110-L127)
  in
  [github.com/sqlxpert/step-stay-stopped-aws-rds-aurora](https://github.com/sqlxpert/step-stay-stopped-aws-rds-aurora#step-stay-stopped-rds-and-aurora)&nbsp;.

- **Minimized parameterization** (Terraform variables and outputs, for the
  purpose of this exercise). My pre-existing projects model extensive
  parameterization for flexibility and template re-use, plus defaults for
  simplicity, complete parameter descriptions, and grouping of essential and
  non-essential parameters. See, for example, CloudFormation
  [`Parameters`](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L9-L288)
  and
  [`Metadata`](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L290-L399)
  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.
  I have also modeled the more AWS-idiomatic and scalable approach of using
  Systems Manager Parameter Store and path hierarchies. See
  [`ClientSecGrpIdParam`](https://github.com/sqlxpert/10-minute-aws-client-vpn/blob/1eb9028/10-minute-aws-client-vpn.yaml#L348-L362)
  in
  [github.com/sqlxpert/10-minute-aws-client-vpn](https://github.com/sqlxpert/10-minute-aws-client-vpn#10-minute-aws-client-vpn)&nbsp;.

### Recommendations

My professional and ethical commitment is simple: Only as much technology as a
business...

- needs,
- can afford,
- understands (or can learn), and
- can maintain.

Having worked for startups since 2013, I always recommend _focusing_
engineering effort during a company's formative years. It is not possible to
do everything, let alone to be good at everything. Managed services,
serverless technologies, and low-code solutions free engineers to focus on a
startup's core product. My recommendations assume that a startup has chosen
AWS as its cloud provider. (Multi-cloud support is not the core business of
most startups.)

|For this feature|The exercise required|I recommend|Because|
|:---|:---|:---|:---|
|API internals|A Docker container|AWS&nbsp;Lambda functions|There is much less infrastructure to specify and maintain, with Lambda. Source code for Lamdba functions of reasonable length can be specified in-line, eliminating the need for a packaging pipeline.|
|Container orchestration|ECS&nbsp;Fargate|ECS&nbsp;Fargate|When containers are truly necessary, ECS requires much less effort than EKS, and Fargate, less than EC2.|
|API presentation|(No requirement)|API&nbsp;Gateway|API&nbsp;Gateway integrates directly with other relevant AWS services, including CloudWatch for logging and monitoring, Web Application Firewall (WAF) for protection from distributed denial of service (DDOS) and other attacks.|
|Data streaming|Apache&nbsp;Kafka, via&nbsp;MSK|Kinesis|Kinesis is serverless, which places the focus on usage rather than on cluster specification and operation.|
|Consumer|An AWS&nbsp;Lambda function|An AWS&nbsp;Lambda function|(As above)|
|Logging|CloudWatch Logs|CloudWatch Logs|CloudWatch Logs is integrated with most AWS services. It requires less software installation effort (agents are included in AWS images) and much less configuration effort than alternatives like DataDog. Caution: CloudWatch is particularly expensive, but other centralized logging and monitoring products also become expensive at scale.|
|Infrastructure as code|Terraform|CloudFormation|CloudFormation:<ul><li>doesn't require the installation and constant upgrading of extra software;</li><li>steers users to simple, AWS-idiomatic resource definitions;</li><li>is covered, at no extra charge, by the existing AWS Support contract; and</li><li>supports creating multiple stacks from the same template, thanks to automatic resource naming.</li></ul>|

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE_CODE.md](/LICENSE_CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE_DOC.md](/LICENSE_DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
