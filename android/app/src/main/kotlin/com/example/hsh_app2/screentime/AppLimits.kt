package com.example.hsh_app2.screentime

/**
 * Per-app daily allowances set by the warden (`daily_limit_minutes` of an app
 * rule). Pure (strings and numbers in, values out) so it runs in plain JVM
 * tests; [PolicyStore] reads the rules from the policy JSON and
 * [PolicyEvaluator] applies [reached].
 */
object AppLimits {
    /**
     * Package → minutes for the rules that have a limit. A rule with no
     * package, or a limit of 0 / missing (no limit), is left out.
     */
    fun fromRules(rules: List<Pair<String, Int?>>): Map<String, Int> {
        val out = LinkedHashMap<String, Int>()
        for ((pkg, minutes) in rules) {
            val p = pkg.trim()
            if (p.isEmpty() || minutes == null || minutes <= 0) continue
            out[p] = minutes.coerceAtMost(24 * 60)
        }
        return out
    }

    /** Whether [packageName] has used up its own daily allowance. */
    fun reached(limits: Map<String, Int>, packageName: String, usedMinutes: Int): Boolean {
        val limit = limits[packageName] ?: return false
        return limit > 0 && usedMinutes >= limit
    }
}
