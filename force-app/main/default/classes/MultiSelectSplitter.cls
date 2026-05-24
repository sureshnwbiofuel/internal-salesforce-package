public class MultiSelectSplitter {
    @InvocableMethod(label='Split Multi-Select Picklist' category='Utility')
    public static List<List<String>> splitValues(List<String> inputStrings) {
        List<List<String>> result = new List<List<String>>();
        for (String s : inputStrings) {
            if (String.isBlank(s)) {
                result.add(new List<String>());
            } else {
                result.add(s.split(';'));
            }
        }
        return result;
    }
}