// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

window.stimulus_controller = function(element_id, controller_name){
  return application.getControllerForElementAndIdentifier(
    document.getElementById(element_id),
    controller_name
  )
}
