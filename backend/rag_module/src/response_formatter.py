import random


class ResponseFormatter:
    """
    Formats raw dataset retrieval results into a conversational, guide-style response.
    """

    def __init__(self):
        self.greetings = [
            "Greetings! 🏛️",
            "Welcome to our heritage exploration! ✨",
            "Hello there! I'm your virtual guide. 🦁",
            "It's a pleasure to share this history with you. 📜",
            "Ah, a great question! Let me tell you more. 🏺",
        ]

        # Core English templates for the categories that appear in the Sigiriya dataset.
        # The factual retrieved text stays source-aligned; the wrapper is language-aware.
        self.templates = {
            "history": [
                "History tells us that {text}. It's truly fascinating how {landmark} has stood the test of time!",
                "This site has such a rich past! {text}. This remains a significant chapter in the story of {landmark}.",
                "To understand this place, we must look back: {text}. This legacy defines {landmark} as we see it today.",
            ],
            "architecture": [
                "The design here is breath-taking! {text}. It's a prime example of ancient craftsmanship at {landmark}. 🏗️",
                "Architecturally speaking, {text}. This structure makes {landmark} quite unique in the world.",
                "Notice the incredible details: {text}. These features are what make {landmark} a true marvel of design.",
            ],
            "engineering": [
                "The engineering prowess here is simply incredible! {text}. Even today, experts marvel at how this was achieved at {landmark}. ⚙️",
                "They were truly way ahead of their time! {text}. This innovation at {landmark} is still studied by modern engineers.",
                "Innovation was key to this site: {text}. Such advanced techniques at {landmark} are simply mind-blowing.",
            ],
            "art": [
                "The artistry here is simply sublime. {text}. These works at {landmark} capture the soul of an ancient era. 🎨",
                "Every brushstroke tells a story of the past. {text}. The artistic heritage here at {landmark} is world-renowned.",
                "As you look at these, remember: {text}. It's a beautiful testament to the vibrant culture of {landmark}.",
            ],
            "culture": [
                "Culturally, {text}. This gives {landmark} its enduring identity and spirit.",
                "There is deep cultural meaning here: {text}. It helps explain why {landmark} matters so much.",
            ],
            "facts": [
                "Here's a key fact: {text}. It adds important context to {landmark}.",
                "A useful detail to remember: {text}. That is one reason {landmark} is so remarkable.",
            ],
            "gardens": [
                "The gardens are a peaceful retreat, aren't they? {text}. They represent the perfect harmony between nature and royalty at {landmark}. 🌿",
                "Imagine walking through these paths centuries ago. {text}. The greenery at {landmark} is still lush and inviting today.",
                "Nature and design meet beautifully here: {text}. These gardens are among the oldest and best-preserved in the region.",
            ],
            "fortress": [
                "This was built to be nearly impenetrable! {text}. Its strategic location gave {landmark} a formidable defensive advantage. 🛡️",
                "Safety and power were paramount for the rulers. {text}. The defensive features of {landmark} are still quite visible today.",
                "Standing here, you can really feel the strength of the place: {text}. A true fortress indeed!",
            ],
            "tourism": [
                "Tourists love this site because {text}. That makes {landmark} a must-visit destination.",
                "From a visitor's perspective, {text}. It is one of the reasons {landmark} attracts travelers year after year.",
            ],
            "archaeology": [
                "Archaeologically speaking, {text}. This evidence helps experts better understand {landmark}.",
                "Excavation and research show that {text}. That is vital to the study of {landmark}.",
            ],
            "religion": [
                "Religiously, {text}. This reflects an important chapter in {landmark}'s spiritual history.",
                "This site also carries strong religious significance: {text}. It shaped {landmark} over centuries.",
            ],
            "environment": [
                "Environmentally, {text}. The natural setting is a major part of {landmark}'s charm.",
                "The surrounding landscape is part of the experience: {text}. It adds to the beauty of {landmark}.",
            ],
            "default": [
                "That's a very interesting point! {text}. {landmark} truly is a place full of wonders for every visitor.",
                "I'm happy to help you with that! {text}. It's one of the many reasons people love visiting {landmark}.",
                "Great question! {text}. It is one of the many highlights that makes {landmark} so special.",
            ],
        }

        self.localized = {
            "en": {
                "greetings": self.greetings,
                "help": "I am your Heritage Guide. How can I help you explore the wonders of Sri Lanka today? 🏛️",
                "thanks": "You're very welcome! 😊 It's my passion to keep these stories alive. Do you have any other questions about our heritage?",
                "no_results": "I'm sorry, I couldn't find specific information about that in my records. Perhaps you could ask something else about this beautiful site? 🏛️",
                "fact_prefix": "✨",
            },
            "hi": {
                "greetings": [
                    "नमस्ते! 🏛️",
                    "हमारी विरासत यात्रा में आपका स्वागत है! ✨",
                    "हैलो! मैं आपका virtual guide हूं. 🦁",
                ],
                "help": "मैं आपका Heritage Guide हूं। आज मैं आपको श्रीलंका की विरासत खोजने में कैसे मदद कर सकता हूं?",
                "thanks": "आपका स्वागत है! 😊 इन विरासत कथाओं को साझा करना मेरे लिए खुशी की बात है। क्या आपका कोई और प्रश्न है?",
                "no_results": "क्षमा करें, मुझे इस विषय पर अपने रिकॉर्ड में स्पष्ट जानकारी नहीं मिली। कृपया इस स्थल के बारे में कोई और प्रश्न पूछें। 🏛️",
                "fact_prefix": "✨ रोचक जानकारी:",
            },
            "zh": {
                "greetings": [
                    "您好！🏛️",
                    "欢迎来到我们的遗产探索之旅！✨",
                    "你好！我是您的 virtual guide。🦁",
                ],
                "help": "我是您的 Heritage Guide。今天我可以如何帮助您探索斯里兰卡的文化遗产？",
                "thanks": "不客气！😊 我很高兴与您分享这些遗产故事。您还有其他问题吗？",
                "no_results": "抱歉，我的资料中没有找到关于该问题的明确信息。您可以问问这个景点的其他内容。🏛️",
                "fact_prefix": "✨ 趣味小知识:",
            },
            "ru": {
                "greetings": [
                    "Здравствуйте! 🏛️",
                    "Добро пожаловать в наше путешествие по наследию! ✨",
                    "Привет! Я ваш virtual guide. 🦁",
                ],
                "help": "Я ваш Heritage Guide. Чем я могу помочь вам в изучении наследия Шри-Ланки сегодня?",
                "thanks": "Пожалуйста! 😊 Мне очень приятно делиться историями этого наследия. Есть ли у вас еще вопросы?",
                "no_results": "Извините, в моих записях не найдено точной информации по этому вопросу. Попробуйте спросить что-то еще об этом месте. 🏛️",
                "fact_prefix": "✨ Интересный факт:",
            },
            "de": {
                "greetings": [
                    "Hallo! 🏛️",
                    "Willkommen zu unserer Entdeckungsreise durch das Kulturerbe! ✨",
                    "Guten Tag! Ich bin Ihr virtual guide. 🦁",
                ],
                "help": "Ich bin Ihr Heritage Guide. Wie kann ich Ihnen heute helfen, das Kulturerbe Sri Lankas zu entdecken?",
                "thanks": "Sehr gerne! 😊 Es ist mir eine Freude, diese Geschichten des Kulturerbes zu teilen. Haben Sie noch weitere Fragen?",
                "no_results": "Entschuldigung, ich konnte dazu keine genauen Informationen in meinen Daten finden. Fragen Sie gern etwas anderes zu diesem Ort. 🏛️",
                "fact_prefix": "✨ Interessanter Fakt:",
            },
            "si": {
                "greetings": [
                    "ආයුබෝවන්! 🏛️",
                    "අපේ උරුම ගවේෂණයට සාදරයෙන් පිළිගනිමු! ✨",
                    "හෙලෝ! මම ඔබගේ virtual guide. 🦁",
                ],
                "help": "මම ඔබගේ Heritage Guide. ශ්‍රී ලංකාවේ උරුම අරුම පුදුම සොයා යාමට අද ඔබට මම කොහොම උදව් කරන්නද?",
                "thanks": "බොහොම ස්තුතියි! 😊 අපේ උරුම කතා ජීවත් කරවීම මගේ සතුටයි. තවත් ප්‍රශ්නයක් තියෙනවද?",
                "no_results": "සමාවෙන්න, ඒ ගැන නිශ්චිත තොරතුරු මගේ වාර්තා වල හමු නොවුණා. මේ ස්ථානය ගැන වෙනත් ප්‍රශ්නයක් අහන්න පුළුවන්. 🏛️",
                "fact_prefix": "✨ අමතර තොරතුරක්:",
            },
            "ta": {
                "greetings": [
                    "வணக்கம்! 🏛️",
                    "எங்கள் பாரம்பரிய பயணத்திற்கு வரவேற்கிறோம்! ✨",
                    "ஹலோ! நான் உங்கள் virtual guide. 🦁",
                ],
                "help": "நான் உங்கள் Heritage Guide. இலங்கையின் பாரம்பரிய அதிசயங்களை அறிய இன்று எப்படி உதவலாம்?",
                "thanks": "மிகுந்த நன்றி! 😊 இந்த பாரம்பரியக் கதைகளை உயிரோட்டமாக வைத்திருப்பது எனக்கு மகிழ்ச்சி. இன்னும் ஏதேனும் கேள்விகள் உள்ளனவா?",
                "no_results": "மன்னிக்கவும், அதைப் பற்றிய குறிப்பிட்ட தகவல் எனது பதிவுகளில் கிடைக்கவில்லை. இந்த அழகான இடத்தைப் பற்றி வேறு கேள்வி கேளுங்கள். 🏛️",
                "fact_prefix": "✨ கூடுதல் தகவல்:",
            },
        }

        for language_code in self.localized:
            self.localized[language_code]["templates"] = self.templates

        self.fun_facts = {
            "sigiriya": [
                "Did you know? Sigiriya is often affectionately called the 'Eighth Wonder of the World'!",
                "Fun fact: The fountains at Sigiriya still work during the rainy season using 1,500-year-old hydraulics!",
                "Interesting detail: There are exactly 1,202 steps to reach the very summit of the rock!",
                "Wait until you see the Mirror Wall – it was once so polished that the King could actually see his reflection!",
            ],
            "dambulla": [
                "Did you know? The Dambulla Cave complex has been a sacred pilgrimage site for over 22 centuries!",
                "Fun fact: There are 153 Buddha statues hidden within these magnificent caves.",
                "Interesting detail: The cave ceilings are covered in intricate paintings that follow the natural curves of the rock.",
            ],
            "polonnaruwa": [
                "Did you know? Polonnaruwa was the second capital of Sri Lanka for over two centuries!",
                "Fun fact: The Gal Vihara features four massive Buddha statues carved from a single granite rock face.",
                "Interesting detail: The Parakrama Samudra is a vast man-made reservoir so large it was called the 'Sea of Parakrama'.",
            ],
        }

    def handle_social_intents(self, query, language="en"):
        """
        Check if the user is just saying hello or thank you and provide a guide-style response.
        """
        normalized_query = query.lower().strip()
        language = language if language in self.localized else "en"
        language_pack = self.localized[language]

        greeting_terms = {
            "en": ["hello", "hi", "hey", "greetings", "good morning", "good afternoon"],
            "hi": ["namaste", "hello", "hi", "hey", "नमस्ते"],
            "zh": ["nihao", "hello", "hi", "hey", "你好", "您好"],
            "ru": ["privet", "hello", "hi", "hey", "привет", "здравствуйте"],
            "de": ["hallo", "hello", "hi", "hey", "guten tag"],
            "si": ["hello", "hi", "hey", "ayubowan", "ආයුබෝවන්"],
            "ta": ["hello", "hi", "hey", "vanakkam", "வணக்கம்"],
        }

        thank_terms = {
            "en": ["thank", "thanks", "thx"],
            "hi": ["thank", "thanks", "thx", "धन्यवाद", "शुक्रिया"],
            "zh": ["thank", "thanks", "thx", "谢谢", "多谢"],
            "ru": ["thank", "thanks", "thx", "спасибо"],
            "de": ["thank", "thanks", "thx", "danke", "danke schoen"],
            "si": ["thank", "thanks", "thx", "ස්තුතියි"],
            "ta": ["thank", "thanks", "thx", "நன்றி"],
        }

        if normalized_query in greeting_terms.get(language, greeting_terms["en"]):
            return random.choice(language_pack["greetings"]) + " " + language_pack["help"]

        if any(word in normalized_query for word in thank_terms.get(language, thank_terms["en"])):
            return language_pack["thanks"]

        return None

    def format_response(self, results, landmark_id, query=None, language="en"):
        """
        Main logic to transform retrieval results into a guide-style response.
        """
        language = language if language in self.localized else "en"
        language_pack = self.localized[language]

        if query:
            social_response = self.handle_social_intents(query, language=language)
            if social_response:
                return social_response

        if not results:
            return language_pack["no_results"]

        top_result = results[0]
        text = top_result.get("text", "").strip()
        category = top_result.get("category", "default")
        landmark = top_result.get("landmark", landmark_id.replace("_", " ").capitalize())

        if text.endswith("."):
            text = text[:-1]

        greeting = random.choice(language_pack["greetings"])
        category_templates = language_pack["templates"].get(category.lower(), language_pack["templates"]["default"])
        template = random.choice(category_templates)
        formatted_text = template.format(text=text, landmark=landmark, category=category)

        fact_str = ""
        if random.random() < 0.4:
            facts = self.fun_facts.get(landmark_id.lower(), [])
            if facts:
                fact_str = f" {language_pack['fact_prefix']} {random.choice(facts)}"

        return f"{greeting} {formatted_text}{fact_str}"
