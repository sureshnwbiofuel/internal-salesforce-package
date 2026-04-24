({
    handleClose : function(component, event, helper) {
        const navEvt = $A.get("e.force:navigateToObjectHome");
        navEvt.setParams({
            scope: "WorkOrder"
        });
        navEvt.fire();
    }
});