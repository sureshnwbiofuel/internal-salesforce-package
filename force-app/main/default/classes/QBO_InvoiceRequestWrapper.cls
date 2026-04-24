/**
 * @description Wrapper class for Outbound Invoice Request
 * Based on provided Sample Request Payload
 */
public class QBO_InvoiceRequestWrapper {
   // public String operationType; // "create_invoice"
    public InPayload inPayload;

    public class InPayload {
        public String DocNumber; // "test-pradp"
        public CustomerRef CustomerRef;
        public String EmailStatus; // "NeedToSend"
        public BillEmail BillEmail;
        public SalesTermRef SalesTermRef;
        public List<Line> Line;
        public List<CustomField> CustomField;
    }

    public class CustomerRef {
        public String value; // "1513"
        public String name; // "McMenamins - Sunnyside"
    }

    public class BillEmail {
        public String Address; // "venkata@nwbiofuel.com"
    }

    public class SalesTermRef {
        public String value; // "3"
        public String name; // "Net 30"
    }

    public class Line {
        public Integer LineNum; // 1
        public String Description; // "125"
        public Decimal Amount; // 172.50
        public String DetailType; // "SalesItemLineDetail"
        public SalesItemLineDetail SalesItemLineDetail;
       // public String WO_Number; // "WO-12345" (Serialized as WO-Number)
    }

    public class SalesItemLineDetail {
        public String ServiceDate; // "2024-04-04"
        public ItemRef ItemRef;
        public TaxCodeRef TaxCodeRef;
        public ClassRef ClassRef;
        public Decimal UnitPrice; // 172.5
        public Decimal Qty; // 1
        public Decimal DiscountAmt; // 0.0
        public Decimal DiscountRate; // 0.0
    }

    public class ItemRef {
        public String name; // "Brown Grease:Grease Trap:125 Gallon Grease Trap"
        public String value; // "61"
    }

    public class TaxCodeRef {
        public String value; // "TAX"
    }
    
    public class ClassRef {
        public String value; // Internal QBO ID for the fixture/location
        public String name;  // Display name (e.g., "Dishwasher")
    }

    public class CustomField {
        public String DefinitionId; // "1"
        public String StringValue; // "IGT-12345"
        public String Type; // "StringType"
        public String Name; // "WO#"
    }

    public String toJson() {
        return JSON.serialize(this).replace('WO_Number', 'WO-Number');
    }
}