 AI Interview Practice App – Short README
An AI-driven interview simulator that asks role-based questions, evaluates your answers, monitors face & eye contact, and provides a final scoreboard.

🚀 Quick Overview
Generate Questions – Choose role (SDE, Data Analyst, CCNA, Flutter) + difficulty (Easy/Medium/Hard).

Answer – Speak via mic or type manually.

Face Monitoring – Live camera checks for face presence and eye contact.

AI Evaluation – Feedback on relevance, correctness, and sample answers.

Dashboard – View past attempts, leaderboard, and detailed score reports.

🛠 Tech Stack
Layer	Tools
Frontend	Flutter (Dart)
Backend	FastAPI (Python)
Database/Auth	Firebase Firestore & Firebase Auth
AI	OpenRouter API (LLM)
Voice	Speech-to-Text / Text-to-Speech
Face	Google ML Kit Face Detection
🏗 Architecture (Simplified)
Flutter App ↔ FastAPI Backend ↔ OpenRouter AI + Firebase

⚙️ Setup (for developers)
Clone repo.

Backend: cd backend, create virtual env, pip install -r requirements.txt, set .env with OpenRouter key & Firebase credentials, run uvicorn main:app --reload.

Frontend: cd frontend, flutter pub get, run on emulator/device.

📈 Key Features Highlight
Adaptive AI questions – based on real job roles.

Instant feedback – helps you improve on the spot.

Face tracking – builds confidence in a simulated environment.

Leaderboard – gamifies learning and practice.

Full-stack integration – demonstrates end-to‑end development.

🔒 Security
API keys stored via .env (excluded from Git).

Firebase security rules protect user data.

CORS and validation in backend.

🧠 What This Project Demonstrates
Full-stack mobile development (Flutter + FastAPI).

Integration of AI APIs.

Real-time camera and voice processing.

Professional Git workflow and clean code structure.

👨‍💻 Author
Nitesh Kanojiya

Built as a Final Year Major Project to showcase AI‑powered interview preparation.
