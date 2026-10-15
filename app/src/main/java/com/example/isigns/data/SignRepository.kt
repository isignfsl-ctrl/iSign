package com.example.isigns.data

import com.example.isigns.model.Sign

object SignRepository {
    val signs: List<Sign> = listOf(
        Sign(1, "Kamusta", "Greetings", "Hello / How are you? — A common greeting. Open palm waved gently side to side.", "Open palm", "Wrist rotation", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
        Sign(2, "Salamat", "Greetings", "Thank you — Fingertips touch chin then move forward, palm open.", "Fingertips together", "Forward motion", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"),
        Sign(3, "Oo", "Greetings", "Yes — Closed fist nods up and down like a head nodding.", "Closed fist", "Nodding motion", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"),
        Sign(4, "Hindi", "Greetings", "No — Open hand shakes side to side like a head shaking.", "Open hand", "Side-to-side", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4"),
        Sign(5, "Paalam", "Greetings", "Goodbye — Open palm waves side to side, similar to Kamusta.", "Open palm", "Waving", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4"),
        Sign(6, "Isa", "Numbers", "One — Index finger raised, other fingers curled into palm.", "Index finger", "Static hold", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"),
        Sign(7, "Dalawa", "Numbers", "Two — Index and middle fingers raised in a V shape.", "Two fingers", "Static hold", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"),
        Sign(8, "Tatlo", "Numbers", "Three — Thumb, index, and middle fingers extended.", "Three fingers", "Static hold", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"),
        Sign(9, "Apat", "Numbers", "Four — All four fingers extended, thumb tucked.", "Four fingers", "Static hold", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4"),
        Sign(10, "Lima", "Numbers", "Five — Open hand, all fingers spread.", "Open palm spread", "Static hold", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"),
        Sign(11, "Sino", "Questions", "Who — Index finger points forward, hand twists slightly.", "Pointing index", "Twist", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4"),
        Sign(12, "Ano", "Questions", "What — Open palms face up, slight shoulder shrug motion.", "Open palms", "Shrug", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4"),
        Sign(13, "Saan", "Questions", "Where — Pointing index finger moves side to side.", "Pointing index", "Side sweep", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4"),
        Sign(14, "Kailan", "Questions", "When — Index finger taps wrist where a watch would be.", "Index finger", "Tap wrist", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
        Sign(15, "Bakit", "Questions", "Why — Fingertips touch forehead then pull forward.", "Fingertips", "Forehead to forward", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"),
        Sign(16, "Kumain", "Actions", "Eat — Fingertips together tap mouth area twice.", "Pinched fingers", "Tap mouth", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4"),
        Sign(17, "Inom", "Actions", "Drink — Hand forms a C shape, tilts toward mouth as if drinking.", "C-shape hand", "Tilt to mouth", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4"),
        Sign(18, "Tulog", "Actions", "Sleep — Open hand moves down over face, fingers close as if eyes closing.", "Open to closed", "Downward motion", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4"),
        Sign(19, "Lakad", "Actions", "Walk — Two fingers (index and middle) 'walk' across the other palm.", "Two fingers walking", "Walking motion", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"),
        Sign(20, "Takbo", "Actions", "Run — Two fingers 'run' quickly across the other palm.", "Two fingers", "Fast walking", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4"),
        Sign(21, "Galit", "Feelings", "Angry — Clawed hand near chest, pulls outward aggressively.", "Claw hand", "Outward pull", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4"),
        Sign(22, "Masaya", "Feelings", "Happy — Open palms circle outward from chest, like radiating joy.", "Open palms", "Circular outward", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4"),
        Sign(23, "Malungkot", "Feelings", "Sad — Fingertips draw down from eyes like tears.", "Fingertips", "Down from eyes", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4"),
        Sign(24, "Pagod", "Feelings", "Tired — Fists rub eyes then arms drop heavily.", "Fists", "Rub then drop", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4"),
        Sign(25, "Mahal", "Feelings", "Love — Arms cross over chest, fists closed, hugging oneself.", "Closed fists", "Cross chest", videoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4"),
    )

    fun getById(id: Int): Sign? = signs.find { it.id == id }

    val categories: List<String> = signs.map { it.category }.distinct()
}
