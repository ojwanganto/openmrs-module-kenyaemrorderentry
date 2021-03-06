<%
    ui.decorateWith("kenyaemr", "standardPage", [ patient: patient])
    ui.includeJavascript("uicommons", "emr.js")
    ui.includeJavascript("uicommons", "angular.min.js")
    ui.includeJavascript("uicommons", "angular-app.js")
    ui.includeJavascript("uicommons", "angular-resource.min.js")
    ui.includeJavascript("uicommons", "angular-common.js")
    ui.includeJavascript("uicommons", "angular-ui/ui-bootstrap-tpls-0.11.2.js")
    ui.includeJavascript("uicommons", "ngDialog/ngDialog.js")
    ui.includeJavascript("uicommons", "filters/display.js")
    ui.includeJavascript("uicommons", "filters/serverDate.js")
    ui.includeJavascript("uicommons", "services/conceptService.js")
    ui.includeJavascript("uicommons", "services/drugService.js")
    ui.includeJavascript("uicommons", "services/encounterService.js")
    ui.includeJavascript("uicommons", "services/orderService.js")
    ui.includeJavascript("uicommons", "services/session.js")

    ui.includeJavascript("uicommons", "directives/select-concept-from-list.js")
    ui.includeJavascript("uicommons", "directives/select-order-frequency.js")
    ui.includeJavascript("uicommons", "directives/select-drug.js")
    ui.includeJavascript("kenyaemrorderentry", "order-model.js")
    ui.includeJavascript("kenyaemrorderentry", "order-entry.js")
    ui.includeJavascript("kenyaemrorderentry", "drugOrders.js")
    ui.includeJavascript("kenyaemrorderentry", "bootstrap.min.js")

    ui.includeCss("uicommons", "ngDialog/ngDialog.min.css")
    ui.includeCss("kenyaemrorderentry", "drugOrders.css")
    ui.includeCss("uicommons", "styleguide/jquery-ui-1.9.2.custom.min.css")
    ui.includeCss("kenyaemrorderentry", "index.css")
    ui.includeCss("kenyaemrorderentry", "bootstrap.min.css")
    ui.includeCss("kenyaemrorderentry", "font-awesome.css")
    ui.includeCss("kenyaemrorderentry", "font-awesome.min.css")
    ui.includeCss("kenyaemrorderentry", "font-awesome.css.map")
    ui.includeCss("kenyaemrorderentry", "fontawesome-webfont.svg")
%>
<style type="text/css">
#new-order input {
  margin:5px;
}
th,td{
 text-align:left;
}
.program {
    float: left;
    width: 20%;
    padding: 10px;
    border-style: solid;
    border-color: gray;
    margin-left: auto;
}
.regimen {
    float: left;
    width: 78%;
    padding: 10px;
    display: block;
    margin: auto;
}
/* Clear floats after the columns */
.row:after {
    content: "";
    display: table;
    clear: both;
}
.navbar .nav > .active {
    background:none;
}
li.active {
  background-color:#b1d8b3;
}
.hide-section{
  display:none;
}
</style>

${ ui.includeFragment("kenyaemr", "prescription/regimenJsonGenerator") }
${ ui.includeFragment("appui", "messages", [ codes: [
        "kenyaemrorderentry.pastAction.REVISE",
        "kenyaemrorderentry.pastAction.DISCONTINUE"
] ])}
<script type="text/javascript">
    window.OpenMRS = window.OpenMRS || {};
    window.OpenMRS.drugOrdersConfig = ${ jsonConfig };
    window.sessionContext = {'locale':'en_GB'}
    window.OpenMRS.activeOrdersPayload=${activeOrdersResponse};
    window.OpenMRS.currentRegimens=${currentRegimens};
</script>

<div class="ke-page-content">
<div id="drug-orders-app" ng-controller="DrugOrdersCtrl" ng-init='init()'>
   <div class="ui-tabs">
      <ul class="ui-tabs-nav ui-helper-reset ui-helper-clearfix ui-widget-header">
         <li ng-repeat="setting in careSettings" class="ui-state-default ui-corner-top"
            ng-class="{ 'ui-tabs-active': setting == careSetting, 'ui-state-active': setting == careSetting }">
            <a class="ui-tabs-anchor" ng-click="setCareSetting(setting)">
            {{ setting | omrsDisplay }}
            </a>
         </li>
      </ul>
      <div class="ui-tabs-panel ui-widget-content">
         <h3>Drug Orders</h3>
         <div id="program-tabs" class="ke-tabs">
            <div class="ke-tabmenu">
               <div class="ke-tabmenu-item disable-on-regimen-change" data-tabid="active_drug_orders">Active Orders</div>
               <div class="ke-tabmenu-item new-order" data-tabid="standard_regimen_orders">Standard Regimen Order</div>
               <div class="ke-tabmenu-item single-order disable-on-regimen-change" data-tabid="new_drug_orders">Other Drugs Order</div>
               <div class="ke-tabmenu-item disable-on-regimen-change" data-tabid="past_drug_orders">Past Drug Orders</div>
            </div>
            <div class="ke-tab single-order-section" data-tabid="new_drug_orders">
               <div class="card">
                  <div class = "card-header">
                     <h4 class = "card-title">
                        Create New Drug Order
                     </h4>
                  </div>
                  <div class="card-body">
                     <form id="new-order" class="sized-inputs css-form" name="newOrderForm" novalidate>
                        <p>
                           <span ng-show="newDraftDrugOrder.action === 'NEW'">
                              <label>New order for:</label>
                              <select-drug ng-model="newDraftDrugOrder.drug" placeholder="Drug" size="40"></select-drug>
                           </span>
                           <strong ng-show="newDraftDrugOrder.action === 'REVISE'">
                           Revised order for: {{ newDraftDrugOrder.drug.display }}
                           </strong>
                        </p>
                        <p ng-show="newDraftDrugOrder.drug">
                           <label class="heading instructions">
                           <span>Instructions</span>
                           <a ng-repeat="dosingType in dosingTypes" tabindex="-1"
                              ng-click="newDraftDrugOrder.dosingType = dosingType.javaClass"
                              ng-class="{ active: newDraftDrugOrder.dosingType == dosingType.javaClass }">
                           <i class="{{ dosingType.icon }}"></i>
                           {{ dosingType.display }}
                           </a>
                           </label>
                           <span ng-if="newDraftDrugOrder.dosingType == 'org.openmrs.SimpleDosingInstructions'">
                              <input ng-model="newDraftDrugOrder.dose" type="number" placeholder="Dose" min="0" required/>
                              <select-concept-from-list ng-model="newDraftDrugOrder.doseUnits" concepts="doseUnits" placeholder="Units" size="5" required></select-concept-from-list>
                              <select-order-frequency ng-model="newDraftDrugOrder.frequency" frequencies="frequencies" placeholder="Frequency" required></select-order-frequency>
                              <select-concept-from-list ng-model="newDraftDrugOrder.route" concepts="routes" placeholder="Route" size="20" required></select-concept-from-list>
                              <br/>
                              <label ng-class="{ disabled: !newDraftDrugOrder.asNeededCondition }">As needed for</label>
                              <input ng-model="newDraftDrugOrder.asNeededCondition" type="text" size="30" placeholder="reason (optional)"/>
                              <br/>
                              <label ng-class="{ disabled: !newDraftDrugOrder.duration }">For</label>
                              <input ng-model="newDraftDrugOrder.duration" type="number" min="0" placeholder="Duration" size="20"/>
                              <select-concept-from-list ng-model="newDraftDrugOrder.durationUnits" concepts="durationUnits" placeholder="Units" size="8" required-if="newDraftDrugOrder.duration"></select-concept-from-list>
                              <label ng-class="{ disabled: !newDraftDrugOrder.duration }">total</label>
                              <br/>
                              <textarea ng-model="newDraftDrugOrder.dosingInstructions" rows="2" cols="60" placeholder="Additional instruction not covered above"></textarea>
                           </span>
                           <span ng-if="newDraftDrugOrder.dosingType == 'org.openmrs.FreeTextDosingInstructions'">
                           <textarea ng-model="newDraftDrugOrder.dosingInstructions" rows="4" cols="60" placeholder="Complete instructions"></textarea>
                           </span>
                        </p>
                        <p ng-if="newDraftDrugOrder.drug && careSetting.careSettingType == 'OUTPATIENT'">
                           <label class="heading">For outpatient orders</label>
                           Dispense:
                           <input ng-model="newDraftDrugOrder.quantity" type="number" min="0" placeholder="Quantity" required/>
                           <select-concept-from-list ng-model="newDraftDrugOrder.quantityUnits" concepts="quantityUnits" placeholder="Units" size="8"></select-concept-from-list>
                        </p>
                        <p ng-show="newDraftDrugOrder.drug">
                           <button type="submit" class="confirm" ng-disabled="newOrderForm.\$invalid" ng-click="addNewDraftOrder()">Add</button>
                           <button class="cancel" ng-click="cancelNewDraftOrder()">Cancel</button>
                        </p>
                     </form>
                     <div id="draft-orders" ng-show="draftDrugOrders.length > 0">
                        <h3>Unsaved Draft Orders ({{ draftDrugOrders.length }})</h3>
                        <table class="ke-table-vertical">
                           <tr class="draft-order" ng-repeat="order in draftDrugOrders">
                              <td>
                                 {{ order.action }}
                                 {{ order | dates }}
                              </td>
                              <td>
                                 {{ order | instructions }}
                                 <span ng-show="order.action == 'DISCONTINUE'">
                                 <br/>
                                 For: <input ng-model="order.orderReasonNonCoded" class="dc-reason" type="text" placeholder="reason" size="40"/>
                                 </span>
                              </td>
                              <td class="actions">
                                 <a ng-click="editDraftDrugOrder(order)"><i class="icon-pencil edit-action"></i></a>
                                 <a ng-click="cancelDraftDrugOrder(order)"><i class="icon-remove delete-action"></i></a>
                              </td>
                           </tr>
                        </table>
                        <div class="actions">
                           <div class="signature">
                              Signing as ${ ui.format(sessionContext.currentProvider) } on (auto-generated timestamp)
                              <img ng-show="loading" src="${ ui.resourceLink("uicommons", "images/spinner.gif") }"/>
                           </div>
                           <button class="confirm right" ng-disabled="loading" ng-click="signAndSaveDraftDrugOrders()">Sign and Save</button>
                           <button class="cancel" ng-click="cancelAllDraftDrugOrders()">
                           {{ draftDrugOrders.length > 1 ? "Discard All" : "Discard" }}
                           </button>
                        </div>
                     </div>

                  </div>
               </div>
            </div>
            <div class="ke-tab new-order-section" data-tabid="standard_regimen_orders">
               <div class="card">
                  <div class = "card-header">
                     <h4 class = "card-title">
                       Standard Regimens
                     </h4>
                  </div>
                  <div class="card-body">
                  <table ng-show="patientRegimens.length > 0">
                  <tr ng-repeat="regimen in patientRegimens" style="font-size:16px;font-weight:bold;">
                  <td style="width:35%;">Current {{regimen.program}} Regimen:{{regimen.name}}</td>
                  <td>
                      <button ng-click="matchRegimenNames(regimen.name)" class="refill-regimen">Refill</button>
                      <!--
                      <button type="button" data-toggle="collapse" data-target="#{{regimen.program}}">
                      ...
                      </button>
                        <div id="{{regimen.program}}" class="collapse">
                          <button class="change-regimen" ng-click="changeRegimen(regimen)">Change</button>
                          <button ng-click="discontinueOrderGroup(regimen.components)" class="stopOrder">Stop</button>
                        </div>
                       -->
                  </td>
                  </tr>
                  </table>
                  <span ng-show="patientRegimens.length==0"> Regimen: Never on Regimen</span>
                   <div ng-show="showRegimenPanel" style="margin-top:2px;">
                      ${ ui.includeFragment("kenyaemrorderentry", "patientdashboard/regimenDispensation", ["patient": patient]) }
                   </div>
                  </div>
               </div>
            </div>
            <div class="ke-tab" data-tabid="active_drug_orders">
               <div class = "card">
                  <div class = "card-header">
                     <h4 class = "card-title">
                        Active Drug Orders
                     </h4>
                  </div>
                  <div class = "card-body">
                     <h5 style="margin:5px;">Standard Regimen Orders</h5>
                     <span ng-show="patientActiveDrugOrders.order_groups.length==0">None</span>
                     <table ng-show="patientActiveDrugOrders.order_groups.length > 0" class="ke-table-vertical">
                        <tr>
                           <th width="30%">Dates</th>
                           <th width="50%">Instructions</th>
                           <th width="20%">Action</th>
                        </tr>
                        <tr ng-repeat="order in patientActiveDrugOrders.order_groups">
                           <td ng-class="{ 'will-replace': replacementFor(order) }">
                              {{ order.date }}
                           </td>
                           <td ng-class="{ 'will-replace': replacementFor(order) }">
                              {{ order.name}}
                           </td>
                           <td>
                              <button ng-click="editOrderGroup(order)" class="edit-order">Edit</button>
                              <button ng-click="discontinueOrderGroup(order.components)" class="dispenseOrder">Dispense</button>
                           </td>
                        </tr>
                     </table>
                     <h5 style="margin:5px;">Other Drug Orders</h5>
                     <span ng-show="activeDrugOrders.loading">${ ui.message("uicommons.loading.placeholder") }</span>
                     <span ng-show="activeDrugOrders.length == 0">None</span>
                     <table ng-show="activeDrugOrders.length > 0" class="ke-table-vertical">
                        <tr>
                           <th width="30%">Dates</th>
                           <th width="50%">Instructions</th>
                           <th width="20%">Action</th>
                        </tr>
                        <tr ng-repeat="order in activeDrugOrders">
                           <td ng-class="{ 'will-replace': replacementFor(order) }">
                              {{ order | dates }}
                           </td>
                           <td ng-class="{ 'will-replace': replacementFor(order) }">
                              {{ order | instructions }}
                           </td>
                           <td class="actions">
                              <a ng-show="!replacementFor(order)" ng-click="reviseOrder(order)" class="edit-single-drug">
                              <button>Edit</button>
                              </a>
                              <a ng-show="!replacementFor(order)" ng-click="discontinueOrder(order)" class="dispense-single-drug">
                              <button>Dispense</button>
                              </a>
                              <span ng-show="replacementFor(order)">
                              will {{ replacementFor(order).action }}
                              </span>
                           </td>
                        </tr>
                     </table>
                  </div>
               </div>
            </div>
            <div class="ke-tab" data-tabid="past_drug_orders">
               <div class = "card">
                  <div class = "card-header">
                     <h4 class = "card-title">
                        Past Drug Orders
                     </h4>
                  </div>
                  <div class = "card-body">
                     <span ng-show="pastDrugOrders.loading">${ ui.message("uicommons.loading.placeholder") }</span>
                     <span ng-hide="pastDrugOrders.loading || pastDrugOrders.length > 0">None</span>
                     <table id="past-drug-orders" ng-hide="pastDrugOrders.loading" class="ke-table-vertical">
                        <tr>
                           <th width="10%">Replacement</th>
                           <th width="20%">Dates</th>
                           <th>Instructions</th>
                        </tr>
                        <tr ng-repeat="order in pastDrugOrders">
                           <td>
                              {{ replacementForPastOrder(order) | replacement }}
                           </td>
                           <td>
                              {{ order | dates }}
                           </td>
                           <td>
                              {{ order | instructions }}
                           </td>
                        </tr>
                     </table>
                  </div>
               </div>
            </div>
         </div>
      </div>
   </div>
</div>
<script type="text/javascript">
    // manually bootstrap angular app, in case there are multiple angular apps on a page
    angular.bootstrap('#drug-orders-app', ['drugOrders']);
</script>
