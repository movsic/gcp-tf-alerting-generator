locals {
  alerts= yamldecode(file("config.yaml"))
}

resource "google_monitoring_alert_policy" "alert_policy" {
  for_each = { for x in local.alerts: sha256(x.description) => x }
  project      = var.project_id
  display_name = each.value.description
  documentation {
   content = each.value.documentation
  }
  combiner = "OR"
  conditions {
    display_name = "Condition 1"
    condition_threshold {
      comparison      = each.value.comparison
      duration        = each.value.duration  
      filter          = "resource.type = \"${each.value.resource_type}\" AND metric.type = \"${each.value.metric_id}\""
      threshold_value = each.value.threshold 
      trigger {
        count = "1"
      }
      dynamic "aggregations" {
        for_each = each.value.aligners

        content {
          alignment_period= aggregations.value.alignment_period
          per_series_aligner = aggregations.value.aligner
          cross_series_reducer = aggregations.value.cross_series_reducer
        }
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval          = "1800s"
      notification_channel_names = [data.google_monitoring_notification_channel.notification_channel.name]
    }
  }

  notification_channels = [data.google_monitoring_notification_channel.notification_channel.name]

  user_labels = {
    severity = each.value.severity
  }
}

data "google_monitoring_notification_channel" "notification_channel" {
  project      = var.project_id
  display_name = var.notification_channel_name
}