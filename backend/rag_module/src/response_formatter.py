import random

class ResponseFormatter:
    """
    Formats raw dataset retrieval results into a conversational, guide-style response.
    """
    def __init__(self):
        # Professional yet friendly greetings for a heritage guide
        self.greetings = [
            "Greetings! 🏛️",
            "Welcome to our heritage exploration! ✨",
            "Hello there! I'm your virtual guide. 🦁",
            "It's a pleasure to share this history with you. 📜",
            "Ah, a great question! Let me tell you more. 🏺"
        ]
        
        # Category-based templates to wrap the factual content
        self.templates = {
            "history": [
                "History tells us that {text}. It's truly fascinating how {landmark} has stood the test of time!",
                "This site has such a rich past! {text}. This remains a significant chapter in the story of {landmark}.",
                "To understand this place, we must look back: {text}. This legacy defines {landmark} as we see it today."
            ],
            "architecture": [
                "The design here is breath-taking! {text}. It's a prime example of ancient craftsmanship at {landmark}. 🏗️",
                "Architecturally speaking, {text}. This structure makes {landmark} quite unique in the world.",
                "Notice the incredible details: {text}. These features are what make {landmark} a true marvel of design."
            ],
            "engineering": [
                "The engineering prowess here is simply incredible! {text}. Even today, experts marvel at how this was achieved at {landmark}. ⚙️",
                "They were truly way ahead of their time! {text}. This innovation at {landmark} is still studied by modern engineers.",
                "Innovation was key to this site: {text}. Such advanced techniques at {landmark} are simply mind-blowing."
            ],
            "art": [
                "The artistry here is simply sublime. {text}. These works at {landmark} capture the soul of an ancient era. 🎨",
                "Every brushstroke tells a story of the past. {text}. The artistic heritage here at {landmark} is world-renowned.",
                "As you look at these, remember: {text}. It's a beautiful testament to the vibrant culture of {landmark}."
            ],
            "gardens": [
                "The gardens are a peaceful retreat, aren't they? {text}. They represent the perfect harmony between nature and royalty at {landmark}. 🌿",
                "Imagine walking through these paths centuries ago. {text}. The greenery at {landmark} is still lush and inviting today.",
                "Nature and design meet beautifully here: {text}. These gardens are among the oldest and best-preserved in the region."
            ],
            "fortress": [
                "This was built to be nearly impenetrable! {text}. Its strategic location gave {landmark} a formidable defensive advantage. 🛡️",
                "Safety and power were paramount for the rulers. {text}. The defensive features of {landmark} are still quite visible today.",
                "Standing here, you can really feel the strength of the place: {text}. A true fortress indeed!"
            ],
            "default": [
                "That's a very interesting point! {text}. {landmark} truly is a place full of wonders for every visitor.",
                "I'm happy to help you with that! {text}. It's one of the many reasons people love visiting {landmark}.",
                "Great question! {text}. It is one of the many highlights that makes {landmark} so special."
            ]
        }

        # Contextual fun facts to add variety
        self.fun_facts = {
            "sigiriya": [
                "Did you know? Sigiriya is often affectionately called the 'Eighth Wonder of the World'!",
                "Fun fact: The fountains at Sigiriya still work during the rainy season using 1,500-year-old hydraulics!",
                "Interesting detail: There are exactly 1,202 steps to reach the very summit of the rock!",
                "Wait until you see the Mirror Wall – it was once so polished that the King could actually see his reflection!"
            ],
            "dambulla": [
                "Did you know? The Dambulla Cave complex has been a sacred pilgrimage site for over 22 centuries!",
                "Fun fact: There are 153 Buddha statues hidden within these magnificent caves.",
                "Interesting detail: The cave ceilings are covered in intricate paintings that follow the natural curves of the rock."
            ],
            "polonnaruwa": [
                "Did you know? Polonnaruwa was the second capital of Sri Lanka for over two centuries!",
                "Fun fact: The Gal Vihara features four massive Buddha statues carved from a single granite rock face.",
                "Interesting detail: The Parakrama Samudra is a vast man-made reservoir so large it was called the 'Sea of Parakrama'."
            ]
        }

    def handle_social_intents(self, query):
        """
        Check if the user is just saying hello or thank you and provide a guide-style response.
        """
        query = query.lower().strip()
        
        # Greeting intents
        if query in ["hello", "hi", "hey", "greetings", "good morning", "good afternoon"]:
            return random.choice(self.greetings) + " I am your Heritage Guide. How can I help you explore the wonders of Sri Lanka today? 🏛️"
            
        # Thank you intents
        if any(word in query for word in ["thank", "thanks", "thx"]):
            return "You're very welcome! 😊 It's my passion to keep these stories alive. Do you have any other questions about our heritage?"

        return None

    def format_response(self, results, landmark_id, query=None):
        """
        Main logic to transform retrieval results into a guide-style response.
        """
        # 0. Check for social intents first
        if query:
            social_response = self.handle_social_intents(query)
            if social_response:
                return social_response

        if not results:
            return "I'm sorry, I couldn't find specific information about that in my records. Perhaps you could ask something else about this beautiful site? 🏛️"

        # We focus on the top result for the primary message
        top_result = results[0]
        text = top_result.get('text', '').strip()
        category = top_result.get('category', 'default')
        landmark = top_result.get('landmark', landmark_id.replace('_', ' ').capitalize())

        # Clean text: remove trailing period if present so it fits better in templates
        if text.endswith('.'):
            text = text[:-1]

        # 1. Randomly pick a guide-style greeting
        greeting = random.choice(self.greetings)

        # 2. Select a template based on the category of the information
        category_templates = self.templates.get(category.lower(), self.templates['default'])
        template = random.choice(category_templates)

        # 3. Build the core response
        formatted_text = template.format(text=text, landmark=landmark, category=category)

        # 4. Occasionally sprinkle in a fun fact (approx 40% chance) to keep it engaging
        fact_str = ""
        if random.random() < 0.4:
            facts = self.fun_facts.get(landmark_id.lower(), [])
            if facts:
                fact_str = f" ✨ {random.choice(facts)}"

        # 5. Final assembly
        final_response = f"{greeting} {formatted_text}{fact_str}"
        
        return final_response
