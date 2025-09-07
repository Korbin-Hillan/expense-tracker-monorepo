# Expense Tracker

This is a full-stack expense tracking application designed to help users manage their finances effectively. The project consists of a web application, a backend API, and a native iOS app.

## Features

- **Dashboard:** A comprehensive overview of your financial status.
- **Transaction Management:** Add, edit, and delete expenses and income.
- **Budgets:** Set and track monthly or categorical budgets.
- **AI Chat:** Get insights and assistance through an AI-powered chat interface.
- **Recurring Expenses:** Manage subscriptions and other recurring payments.
- **Data Import/Export:** Import transactions from CSV files and export your data.
- **Rules Engine:** Create rules to automatically categorize transactions.
- **Integrations:** Connect with external services.
- **User Authentication:** Secure user accounts with password and social login options.
- **Multi-platform:** Access your data on the web or via the native iOS application.

## Project Structure

The repository is a monorepo containing three main projects:

- **`frontend/`**: A React (Vite + TypeScript) single-page application for the web interface.
- **`backend/`**: A Node.js (Express + TypeScript) server that provides the REST API for the web and mobile clients.
- **`ios/`**: A native iOS application built with SwiftUI.
- **`docs/`**: Static HTML documentation and privacy policy.
- **`support-site/`**: Placeholder for a future support website.

## Tech Stack

- **Backend**: Node.js, Express, TypeScript, MongoDB, BullMQ, Pino, Jest
- **Frontend**: React, TypeScript, Vite, React Router
- **iOS**: Swift, SwiftUI

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or later recommended)
- [npm](https://www.npmjs.com/)
- [MongoDB](https://www.mongodb.com/try/download/community) instance (local or cloud)
- [Xcode](https://developer.apple.com/xcode/) (for iOS development)

### Backend Setup

1.  **Navigate to the backend directory:**
    ```bash
    cd backend
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Configure environment variables:**
    Create a `.env` file in the `backend` directory by copying the `.env.example` (if one exists) and fill in the required values, such as your MongoDB connection string and JWT secrets.

4.  **Run the development server:**
    ```bash
    npm start
    ```
    The backend API will be running on `http://localhost:3000`.

5.  **Run tests:**
    ```bash
    npm test
    ```

### Frontend Setup

1.  **Navigate to the frontend directory:**
    ```bash
    cd frontend
    ```

2.  **Install dependencies:**
    ```bash
    npm install
    ```

3.  **Run the development server:**
    ```bash
    npm run dev
    ```
    The web application will be available at `http://localhost:5173`.

4.  **Build for production:**
    ```bash
    npm run build
    ```

## iOS Application

The native iOS application is located in the `ios/` directory.

1.  **Open the project in Xcode:**
    ```bash
    open ios/IOS-expense-tracker.xcodeproj
    ```

2.  **Configure the backend URL:**
    You will need to update the API client within the Xcode project to point to your running backend instance (e.g., `http://localhost:3000`).

3.  **Build and run:**
    Select a simulator or a connected device and press the "Run" button in Xcode.

## License

This project is proprietary. All rights reserved.
