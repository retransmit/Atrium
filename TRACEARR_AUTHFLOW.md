# Tracearr Internal Authentication Guide

This documentation outlines the authentication flows required to access Tracearr's internal, undocumented API routes (such as `/api/v1/sessions/active`). 

Because Tracearr's official REST API is read-only and strips sensitive data (like geolocation), third-party applications must emulate a web dashboard session to retrieve full payloads. Tracearr supports two primary authentication methods: **Local Authentication** and **Plex Single Sign-On (SSO)**.

---

## Method 1: Local Authentication (Username/Password)

This is the most straightforward method for scripts and headless applications. It requires the user to have a local account configured in the Tracearr settings.

### 1. Request a Session Token
Send a `POST` request with the user's credentials to the local sign-in endpoint.

**Endpoint:** `POST /api/v1/auth/sign-in/username`
**Content-Type:** `application/json`

**Request Body:**
```json
{
  "username": "your_username",
  "password": "your_password"
}
```

**cURL Example:**
```bash
curl -s -X POST "http://localhost:3030/api/v1/auth/sign-in/username" \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password"}' | jq -r '.token'
```

**Response:**
The server will return a JSON object containing user details and a session `token`. If parsing via CLI, the command above extracts the raw token string (e.g., `x0PzNqDgbvV1mRTJiVxVe3K9Zhm5BdVN`).

---

## Method 2: Plex Single Sign-On (SSO)

For users who log into Tracearr exclusively via Plex, you must implement the Plex PIN Auth Flow. Your application will act as an intermediary, obtaining an auth token from Plex and passing it to Tracearr.

### Step 1: Request a Plex PIN
Your application must first request a unique PIN from the official Plex API. 

**Endpoint:** `POST https://plex.tv/api/v2/pins`
**Required Headers:**
*   `X-Plex-Product`: Your App Name
*   `X-Plex-Client-Identifier`: A generated unique ID for your app instance

**cURL Example:**
```bash
curl -s -X POST "[https://plex.tv/api/v2/pins?strong=true](https://plex.tv/api/v2/pins?strong=true)" \
  -H "Accept: application/json" \
  -H "X-Plex-Product: MyTracearrApp" \
  -H "X-Plex-Client-Identifier: app-uuid-12345"
```
**Response:** You will receive an `id` (the PIN ID) and a `code` (the user-facing code).

### Step 2: Prompt the User
Display the `code` to your user in your app's UI and instruct them to navigate to `https://plex.tv/link` to enter it.

### Step 3: Poll for the Plex Token
While the user is authenticating in their browser, your app should poll the Plex API every 3-5 seconds using the PIN `id` from Step 1.

**Endpoint:** `GET https://plex.tv/api/v2/pins/{pin_id}`
*(Include the same `X-Plex-Client-Identifier` header as Step 1)*

Once the user successfully links the code, this endpoint's response will update to include a valid `authToken`.

### Step 4: Authenticate with Tracearr
Now that you have the user's Plex `authToken`, pass it to Tracearr's internal Plex login endpoint to establish the session.

**Endpoint:** `POST /api/v1/auth/sign-in/plex`
**Content-Type:** `application/json`

**Request Body:**
```json
{
  "authToken": "the_token_retrieved_from_plex"
}
```

**Response:**
Tracearr will validate the token with Plex, log the user in, and return the exact same Tracearr `.token` structure as the Local Authentication method.

---

## Using the Auth Token

Once you have successfully extracted the Tracearr `.token` (from either Method 1 or Method 2), you can use it to authorize requests to hidden endpoints.

### Making Authenticated Requests
Pass the token in the `Authorization` header as a Bearer token.

**cURL Example:**
```bash
curl -s -X GET "http://localhost:3030/api/v1/sessions/active" \
  -H "Authorization: Bearer x0PzNqDgbvV1mRTJiVxVe3K9Zhm5BdVN" | jq
```

**Note:** If the Bearer header is rejected by specific strict internal endpoints, you may need to pass the token as a cookie instead (`Cookie: trr-session=x0PzNqDgbvV1mRTJiVxVe3K9Zhm5BdVN`), depending on the specific middleware implementation of the Tracearr version you are targeting.
