namespace ConsoleApp1
{
    public class Solution
    {
        // 5.1 — Prefix & Suffix Arrays Approach
        // Time Complexity: O(n) — three linear passes over the array of length n.
        // Space Complexity: O(n) — uses two auxiliary arrays (prefix[] and suffix[]) of size n each.
        public int[] ProductExceptSelfWithArrays(int[] nums)
        {
            int n = nums.Length;
            int[] prefix = new int[n];
            int[] suffix = new int[n];
            int[] result = new int[n];

            prefix[0] = 1;
            for (int i = 1; i < n; i++)
            {
                prefix[i] = prefix[i - 1] * nums[i - 1];
            }

            suffix[n - 1] = 1;
            for (int i = n - 2; i >= 0; i--)
            {
                suffix[i] = suffix[i + 1] * nums[i + 1];
            }

            for (int i = 0; i < n; i++)
            {
                result[i] = prefix[i] * suffix[i];
            }

            return result;
        }

        // 5.2 — Follow-up: O(1) Extra Space Approach (the output array does not count)
        // Time Complexity: O(n) — two linear passes (left-to-right, then right-to-left).
        // Space Complexity: O(1) — auxiliary space beyond the returned result[] array is a single variable.
        public int[] ProductExceptSelf(int[] nums)
        {
            int n = nums.Length;
            int[] result = new int[n];

            result[0] = 1;
            for (int i = 1; i < n; i++)
            {
                result[i] = result[i - 1] * nums[i - 1];
            }

            int suffix = 1;
            for (int i = n - 1; i >= 0; i--)
            {
                result[i] *= suffix;
                suffix *= nums[i];
            }

            return result;
        }
    }
}
