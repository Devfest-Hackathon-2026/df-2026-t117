package jp.tasuku.ar_guide.ar

enum class Turn {
    LEFT,
    RIGHT,
    STRAIGHT;

    companion object {
        /** Unknown or missing values fall back to RIGHT (the demo default, same as the Dart side). */
        fun parse(value: String?): Turn = when (value?.lowercase()) {
            "left" -> LEFT
            "straight" -> STRAIGHT
            else -> RIGHT
        }
    }
}
