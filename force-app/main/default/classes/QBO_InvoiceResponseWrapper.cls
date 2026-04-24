/**
 * @description Wrapper class for Inbound Invoice Response
 * Based on provided Sample Response Payload
 */
public class QBO_InvoiceResponseWrapper {
    public Invoice Invoice;
    public String time_x; // "2026-04-03T23:29:37.930-07:00"

    public class Invoice {
        public String Id; // "127806"
        public String SyncToken; // "0"
        public String DocNumber; // "test-pradp"
        public String InvoiceLink; // "https://connect.intuit.com/portal/app/..."
        public String TxnDate; // "2026-04-03"
        public String DueDate; // "2026-04-03"
        public Decimal TotalAmt; // 787.5
        public Decimal Balance; // 787.5
        public String PrintStatus; // "NeedToPrint"
        public String EmailStatus; // "NeedToSend"
        public MetaData MetaData;
        public List<Line> Line;
        public TxnTaxDetail TxnTaxDetail;
        public BillAddr BillAddr;
        public ShipAddr ShipAddr;
        public DeliveryInfo DeliveryInfo;
    }

    public class MetaData {
        public String CreateTime; // "2026-04-03T23:29:39-07:00"
        public String LastUpdatedTime; // "2026-04-03T23:29:39-07:00"
    }

    public class Line {
        public String Id; // "1"
        public Integer LineNum; // 1
        public String Description; // "125"
        public Decimal Amount; // 172.5
        public String DetailType; // "SalesItemLineDetail" or "SubTotalLineDetail"
        public SalesItemLineDetail SalesItemLineDetail;
    }

    public class SalesItemLineDetail {
        public ItemAccountRef ItemAccountRef;
        public TaxCodeRef TaxCodeRef;
    }

    public class ItemAccountRef {
        public String value; // "161"
        public String name; // "10210 Brown Grease Services..."
    }

    public class TaxCodeRef {
        public String value; // "TAX"
    }

    public class TxnTaxDetail {
        public Decimal TotalTax; // 0
    }

    public class BillAddr {
        public String Line1; // "430 N Killingsworth St."
        public String City; // "Portland"
        public String CountrySubDivisionCode; // "OR"
        public String PostalCode; // "97217"
    }

    public class ShipAddr {
        public String Line1; // "9757 SE Sunnyside Rd."
        public String City; // "Clackamas"
        public String CountrySubDivisionCode; // "OR"
        public String PostalCode; // "97015"
    }

    public class DeliveryInfo {
        public String DeliveryType; // "Email"
    }

    public static QBO_InvoiceResponseWrapper parse(String json) {
        return (QBO_InvoiceResponseWrapper) System.JSON.deserialize(
            json.replace('"time":', '"time_x":'), 
            QBO_InvoiceResponseWrapper.class
        );
    }
}