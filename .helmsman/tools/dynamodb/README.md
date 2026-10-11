# DynamoDB

`.helmsman/tools/dynamodb/check.sh` validates tracked JSON whose path contains `dynamo` or sits under `dynamodb/`. Each file must be a JSON object with `TableName`, `AttributeDefinitions`, `KeySchema`, or a CloudFormation `Resources` block.

No AWS calls. An `sst.config.ts` or a file under `infra/`, `lib/`, or `stacks/` that mentions DynamoDB, with no table JSON, skips and says the source is the definition.

No consumer of this shape was in the inventory. The package stays generic.
