variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "prefix" { type = string }
variable "tags" { type = map(string) }
variable "health_url" { type = string }
variable "predict_url" { type = string }
variable "golden_request_body" { type = string }
variable "alert_email" { type = string }

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "ai" {
  name                = "appi-${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags                = var.tags
}

# Liveness only. A model that is up and returning the *wrong* predictions
# still passes this test. Do not treat /health as the Task 3 observe signal.
resource "azurerm_application_insights_web_test" "health" {
  name                    = "wt-health-${var.prefix}"
  resource_group_name     = var.resource_group_name
  location                = var.location
  application_insights_id = azurerm_application_insights.ai.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]
  tags = merge(var.tags, {
    "hidden-link:${azurerm_application_insights.ai.id}" = "Resource"
  })

  configuration = <<XML
<WebTest Name="inference-health" Id="a1b2c3d4-e5f6-7890-abcd-ef1234567890" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="b2c3d4e5-f6a7-8901-bcde-f12345678901" Version="1.1" Url="${var.health_url}" ThinkTime="0" Timeout="30" ParseDependentRequests="False" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML
}

resource "azurerm_monitor_action_group" "alerts" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "ag-${var.prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "mlopsag"
  tags                = var.tags

  email_receiver {
    name          = "ops"
    email_address = var.alert_email
  }
}

# TODO(task3): Add an ML-aware observe signal. The grader deploys a known-bad
# model that stays up (/health 200) and returns the wrong predictions.
# A /health ping will not fire. One valid approach:
#
# resource "azurerm_application_insights_standard_web_test" "golden_predict" {
#   name                    = "wt-golden-${var.prefix}"
#   resource_group_name     = var.resource_group_name
#   location                = var.location
#   application_insights_id = azurerm_application_insights.ai.id
#   frequency               = 300
#   timeout                 = 30
#   enabled                 = true
#   retry_enabled           = true
#   geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]
#   tags = merge(var.tags, {
#     "hidden-link:${azurerm_application_insights.ai.id}" = "Resource"
#   })
#   request {
#     url       = var.predict_url
#     http_verb = "TODO" # POST the golden payload
#     body      = var.golden_request_body
#     header {
#       name  = "Content-Type"
#       value = "application/json"
#     }
#   }
#   validation_rules {
#     expected_status_code = 200
#     ssl_check_enabled    = false
#     content {
#       content_match      = "TODO" # substring of the /predict JSON body for the golden payload
#       ignore_case        = false
#       pass_if_text_found = true
#     }
#   }
# }
#
# Then a metric alert on that web test (scope both the test and this App Insights
# component) that notifies azurerm_monitor_action_group.alerts. Set alert_email
# at apply time (tip: use a dynamic "action" block with for_each = azurerm_monitor_action_group.alerts).
# Mechanism is your choice; the grader only checks that an enabled
# alert fires while prod stays healthy and /predict is wrong.

output "appinsights_name" {
  value = azurerm_application_insights.ai.name
}

output "appinsights_connection_string" {
  value     = azurerm_application_insights.ai.connection_string
  sensitive = true
}
