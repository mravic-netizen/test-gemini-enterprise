terraform {
  backend "gcs" {
    bucket  = "tf-state-ge-test"
    prefix  = "asco"
  }
}