# OpenSearch

`.helmsman/tools/opensearch/check.sh` validates tracked JSON whose path mentions OpenSearch or Elasticsearch, or that lives under `mappings/` or `index-templates/`. A file whose name contains `mapping` must include a `mappings` object.

No cluster calls. No consumer of this shape was in the inventory. The package stays generic.
