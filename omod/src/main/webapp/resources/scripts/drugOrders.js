angular.module('drugOrders', ['orderService', 'encounterService', 'uicommons.filters', 'uicommons.widget.select-concept-from-list',
    'uicommons.widget.select-order-frequency', 'uicommons.widget.select-drug', 'session', 'orderEntry']).

    config(function($locationProvider) {
        $locationProvider.html5Mode({
            enabled: true,
            requireBase: false
        });
    }).

    filter('dates', ['serverDateFilter', function(serverDateFilter) {
        return function(order) {
            if (!order || typeof order != 'object') {
                return "";
            }
            if (order.action === 'DISCONTINUE' || !order.dateActivated) {
                return "";
            } else {
                var text = serverDateFilter(order.dateActivated);
                if (order.dateStopped) {
                    text += ' - ' + serverDateFilter(order.dateStopped);
                }
                else if (order.autoExpireDate) {
                    text += ' - ' + serverDateFilter(order.autoExpireDate);
                }
                return text;
            }
        }
    }]).

    filter('instructions', function() {
        return function(order) {
            if (!order || typeof order != 'object') {
                return "";
            }
            if (order.action == 'DISCONTINUE') {
                return "Discontinue " + (order.drug ? order.drug : order.concept ).display;
            }
            else {
                var text = order.getDosingType().format(order);
                if (order.quantity) {
                    text += ' (Dispense: ' + order.quantity + ' ' + order.quantityUnits.display + ')';
                }
                return text;
            }
        }
    }).

    filter('replacement', ['serverDateFilter', function(serverDateFilter) {
        // given the order that replaced the one we are displaying, display the details of the replacement
        return function(replacementOrder) {
            if (!replacementOrder) {
                return "";
            }
            return emr.message("kenyaemrorderentry.pastAction." + replacementOrder.action) + ", " + serverDateFilter(replacementOrder.dateActivated);
        }
    }]).

    controller('DrugOrdersCtrl', ['$scope', '$window', '$location', '$timeout', 'OrderService', 'EncounterService', 'SessionInfo', 'OrderEntryService',
        function($scope, $window, $location, $timeout, OrderService, EncounterService, SessionInfo, OrderEntryService) {

            var orderContext = {};
            SessionInfo.get().$promise.then(function(info) {
                orderContext.provider = info.currentProvider;
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftOrder(orderContext);
            });

            // TODO changing dosingType of a draft order should reset defaults (and discard non-defaulted properties)
            var programRegimens=OpenMRS.kenyaemrRegimenJsonPayload;
            var currentRegimens=OpenMRS.currentRegimens;
            $scope.showRegimenPanel=false;
            function loadExistingOrders() {
                $scope.activeDrugOrders = { loading: true };
                OrderService.getOrders({
                    t: 'drugorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid
                }).then(function(results) {
                    $scope.activeDrugOrders = _.map(OpenMRS.activeOrdersPayload.single_drugs, function(item) {
                    return new OpenMRS.DrugOrderModel(item) });
                    $scope.programs=programRegimens;
                    $scope.regimenLines=$scope.programs.programs[0].regimen_lines;
                    $scope.patientActiveDrugOrders=OpenMRS.activeOrdersPayload;
                    $scope.patientRegimens=currentRegimens.patientregimens;
                    $scope.regimenStatus="absent";
                    if($scope.patientRegimens.length==0){
                      $scope.showRegimenPanel=false;
                    }

                });

                $scope.pastDrugOrders = { loading: true };
                OrderService.getOrders({
                    t: 'drugorder',
                    v: 'full',
                    patient: config.patient.uuid,
                    careSetting: $scope.careSetting.uuid,
                    status: 'inactive'
                }).then(function(results) {
                    $scope.pastDrugOrders = _.map(results, function(item) { return new OpenMRS.DrugOrderModel(item) });
                });
            }


            function replaceWithUuids(obj, props) {
                var replaced = angular.extend({}, obj);
                _.each(props, function(prop) {
                    if (replaced[prop] && replaced[prop].uuid) {
                        replaced[prop] = replaced[prop].uuid;
                    }
                });
                return replaced;
            }

            $scope.loading = false;

            $scope.activeDrugOrders = { loading: true };
            $scope.pastDrugOrders = { loading: true };
            $scope.draftDrugOrders = [];
            $scope.dosingTypes = OpenMRS.dosingTypes;

            var config = OpenMRS.drugOrdersConfig;
            $scope.init = function() {
                $scope.routes = config.routes;
                $scope.doseUnits = config.doseUnits;
                $scope.durationUnits = config.durationUnits;
                $scope.quantityUnits = config.quantityUnits;
                $scope.frequencies = config.frequencies;
                $scope.careSettings = config.careSettings;
                $scope.careSetting = config.intialCareSetting ?
                    _.findWhere(config.careSettings, { uuid: config.intialCareSetting }) :
                    config.careSettings[0];

                orderContext.careSetting = $scope.careSetting;

                loadExistingOrders();

                $timeout(function() {
                    angular.element('#new-order input[type=text]').first().focus();
                });
            }
            // functions that affect the overall state of the page

            $scope.setCareSetting = function(careSetting) {
                // TODO confirm dialog or undo functionality if this is going to discard things
                $scope.careSetting = careSetting;
                orderContext.careSetting = $scope.careSetting;
                loadExistingOrders();
                $scope.draftDrugOrders = [];
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftOrder(orderContext);
                $location.search({ patient: config.patient.uuid, careSetting: careSetting.uuid });
            }


            // functions that affect the new order being written

            $scope.addNewDraftOrder = function() {
                if ($scope.newDraftDrugOrder.getDosingType().validate($scope.newDraftDrugOrder)) {
                    $scope.newDraftDrugOrder.asNeeded = $scope.newDraftDrugOrder.asNeededCondition ? true : false;
                    $scope.draftDrugOrders.push($scope.newDraftDrugOrder);
                    $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftOrder(orderContext);
                    $scope.newOrderForm.$setPristine();
                    // TODO upgrade to angular 1.3 and work on form validation
                    $scope.newOrderForm.$setUntouched();
                } else {
                    emr.errorMessage("Invalid");
                }
            }

            $scope.cancelNewDraftOrder = function() {
                $scope.newDraftDrugOrder = OpenMRS.createEmptyDraftOrder(orderContext);
            }


            // functions that affect the shopping cart of orders written but not yet saved

            $scope.cancelAllDraftDrugOrders = function() {
                $scope.draftDrugOrders = [];
            }

            $scope.cancelDraftDrugOrder = function(draftDrugOrder) {
                $scope.draftDrugOrders = _.without($scope.draftDrugOrders, draftDrugOrder);
            }

            $scope.editDraftDrugOrder = function(draftDrugOrder) {
                $scope.draftDrugOrders = _.without($scope.draftDrugOrders, draftDrugOrder);
                $scope.newDraftDrugOrder = draftDrugOrder;
            }

            /**
             * Finds the replacement order for a given active order (e.g. the order that will DC or REVISE it)
             */
            $scope.replacementFor = function(activeOrder) {
                var lookAt = $scope.newDraftDrugOrder ?
                    _.union($scope.draftDrugOrders, [$scope.newDraftDrugOrder]) :
                    $scope.draftDrugOrders;
                return _.findWhere(lookAt, { previousOrder: activeOrder });
            }

            $scope.replacementForPastOrder = function(pastOrder) {
                var candidates = _.union($scope.activeDrugOrders, $scope.pastDrugOrders)
                return _.find(candidates, function(item) {
                    return item.previousOrder && item.previousOrder.uuid === pastOrder.uuid;
                });
            }

            $scope.signAndSaveDraftDrugOrders = function() {
                var encounterContext = {
                    patient: config.patient,
                    encounterType: config.drugOrderEncounterType,
                    location: null, // TODO
                    encounterRole: config.encounterRole
                };

                $scope.loading = true;
                OrderEntryService.signAndSave({ draftOrders: $scope.draftDrugOrders }, encounterContext)
                    .$promise.then(function(result) {
                        location.href = location.href;
                    }, function(errorResponse) {
                        emr.errorMessage(errorResponse.data.error.message);
                        $scope.loading = false;
                    });
            }


            // functions that affect existing active orders

            $scope.discontinueOrder = function(activeOrder) {
                var dcOrder = activeOrder.createDiscontinueOrder(orderContext);
                $scope.draftDrugOrders.push(dcOrder);
                $scope.$broadcast('added-dc-order', dcOrder);
            }

            $scope.reviseOrder = function(activeOrder) {
                $scope.newDraftDrugOrder = activeOrder.createRevisionOrder();
            }


            // events

            $scope.$on('added-dc-order', function(dcOrder) {
                $timeout(function() {
                    angular.element('#draft-orders input.dc-reason').last().focus();
                });
            });
            $scope.activeRegimens=[];
            $scope.components=[];
            $scope.components.quantity=[];
            $scope.setProgramRegimens=function(regimens){
            $scope.activeRegimens=[];
            $scope.oldComponents=[];
            $scope.regimenDosingInstructions="";
             $scope.activeRegimens=regimens;
            }
            $scope.setRegimenMembers=function(regimen){
            console.log("regimen selected++++++++++++++++++++"+JSON.stringify(regimen));
              $scope.components=[];
              $scope.components=regimen.components;
              orderSetId=regimen.orderSetId;
            }
            $scope.setRegimenLines=function(regimenLine){
              $scope.regimenLines=[];
              $scope.activeRegimens=[];
              $scope.regimenLines=regimenLine;
            }
            window.drugOrderMembers=[];
            window.orderSetSelected={};
            window.regimenDosingInstructions=null;
            $scope.saveOrderSet=function(orderset){
            drugOrderMembers=orderset;
            regimenDosingInstructions=$scope.regimenDosingInstructions;
            console.log("regimendosinginstructions+++++++++++++++++++++++++++++++"+$scope.regimenDosingInstructions);
            }
            window.activeOrderGroupUuId=null;
            window.discontinueOrderUuId=null;
            $scope.editOrderGroup=function(orderGroup){
                _.map($scope.programs.programs, function(program) {
                _.map(program.regimen_lines, function(regimenLine) {
                    _.map(regimenLine.regimens, function(regimen) {
                       if(regimen.name===orderGroup.name){
                        console.log("regimen to edit++++++++++++++++++++"+JSON.stringify(orderGroup));
                        $scope.components=orderGroup.components;
                        orderSetId=regimen.orderSetId;
                        activeOrderGroupUuId=orderGroup.orderGroupUuId;
                        $scope.regimenDosingInstructions=orderGroup.instructions;
                        $scope.showRegimenPanel=true;
                        $scope.regimenStatus='edit';
                       }
                    });
                });

                });
            }
            $scope.discontinueOrderGroup=function(components){
                drugOrderMembers=components;
                orderSetId=null;
                discontinueOrderUuId=null;
            }
            $scope.changeRegimen=function(currentRegimen){
              console.log("components to be changed++++++++++++++++++++"+JSON.stringify(currentRegimen));
              $scope.regimenStatus='change';
              $scope.showRegimenPanel=true;
            }
            $scope.stopRegimen=function(regimen){
            console.log("regimen to stop++++++++++++++++++++"+JSON.stringify(regimen));
              $scope.components=[];
              $scope.components=regimen.components;
              $scope.regimenStatus='stopped';
            }
            $scope.refillRegimen=function(regimen){
            console.log("regimen selected++++++++++++++++++++"+JSON.stringify(regimen));
              $scope.components=[];
              $scope.components=regimen.components;
              orderSetId=regimen.orderSetId;
              $scope.regimenStatus='active';
              $scope.showRegimenPanel=true;
              $scope.matchSetMembers(regimen.components);
            }
            $scope.matchSetMembers=function(members){
            _.map($scope.programs.programs, function(program) {
            _.map(program.regimen_lines, function(regimenLine) {
                _.map(regimenLine.regimens, function(regimen) {
                 var drugsFromOrderSet=$scope.createDrugsArrayFromPayload(regimen.components);
                 var drugsFromCurrentRegimen=$scope.createDrugsArrayFromPayload(members);
                 if($scope.arraysEqual(drugsFromOrderSet,drugsFromCurrentRegimen)){
                console.log("current regimen matches this order set+++++"+JSON.stringify(regimen));
                orderSetId=regimen.orderSetId;
                 }
                });
                });
                });
            }
        $scope.matchRegimenNames=function(name){
        _.map(programRegimens.programs, function(program) {
               _.map(program.regimen_lines, function(regimenLine) {
                    _.map(regimenLine.regimens, function(regimen) {
                    if(regimen.name===name){
                    $scope.programs=[];
                    var programs_array=[];
                    var program_object={};
                    program_object.name=program.name;
                    var regimen_line_object={};
                    regimen_line_object.name=regimenLine.name;

                    var regimen_object={};
                    regimen_object.name=name;
                    regimen_object.components=regimen.components;
                    regimen_line_object.regimens=[];
                    regimen_line_object.regimens.push(regimen_object);
                    program_object.regimen_lines=[];
                    program_object.regimen_lines.push(regimen_line_object);
                    programs_array.push(program_object);
                    $scope.programs={"programs":programs_array};
                    $scope.regimenLines=[];
                    $scope.activeRegimens=[];
                    $scope.regimenLines.push(regimen_line_object);
                    $scope.activeRegimens.push(regimen_object);
                    console.log("contrived programs+++++++++++++++++++"+JSON.stringify($scope.programs));

                    $scope.components=[];
                    $scope.components=regimen.components;
                    orderSetId=regimen.orderSetId;
                    $scope.regimenStatus='active';
                    $scope.showRegimenPanel=true;
                    }
                    });
               });
          });
        }
        $scope.createDrugsArrayFromPayload=function (components){
        var drugs=[];
        var i;
        for(i=0;i<components.length;i++){
        var drug_id=components[i].drug_id;
        if(typeof drug_id=="string"){
        drug_id=parseInt(drug_id);
        }
        drugs.push(drug_id);
        }
        drugs.sort(function(a, b){return a - b});
        return drugs;
        }
        $scope.arraysEqual=function (arr1, arr2) {
            if(arr1.length !== arr2.length)
                return false;
            for(var i = arr1.length; i--;) {
                if(arr1[i] !== arr2[i])
                    return false;
            }

            return true;
        }
        }]);
