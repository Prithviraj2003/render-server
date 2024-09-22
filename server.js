const express = require("express");
const axios = require("axios");
const cors = require("cors");
const app = express();
const port = 5000;
const { exec } = require("child_process");
const dotenv = require("dotenv");
dotenv.config();
console.log(process.env.GITHUB_CLIENT_ID);

app.use(cors()); // Enable CORS for cross-origin requests
app.use(express.json());

const accessTokens = [];

// Step 1: GitHub OAuth callback
app.get("/auth/callback", async (req, res) => {
  const code = req.query.code;
  if (!code) {
    return res.status(400).send("No code provided");
  }

  try {
    // Step 2: Exchange code for access token
    const response = await axios.post(
      "https://github.com/login/oauth/access_token",
      {
        client_id: process.env.GITHUB_CLIENT_ID,
        client_secret: process.env.GITHUB_CLIENT_SECRET,
        code,
      },
      {
        headers: {
          Accept: "application/json",
        },
      }
    );

    const accessToken = response.data.access_token;
    console.log("Access Token:", accessToken);

    // Step 3: Fetch user data using access token
    const userResponse = await axios.get("https://api.github.com/user", {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    const userData = userResponse.data;
    accessTokens[userData.login] = accessToken;

    // Step 4: Redirect back to frontend with username
    res.redirect(`http://localhost:3000?username=${userData.login}`);
  } catch (error) {
    console.error(error);
    res.status(500).send("Authentication failed");
  }
});

// New endpoint to get repositories
app.get("/repos", async (req, res) => {
  const { username } = req.query;

  if (!username || !accessTokens[username]) {
    return res.status(401).send("Unauthorized");
  }

  try {
    // Fetch repositories including private ones
    const response = await axios.get("https://api.github.com/user/repos", {
      headers: {
        Authorization: `Bearer ${accessTokens[username]}`,
      },
      params: {
        visibility: "all", // Include private repos
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send("Failed to fetch repositories");
  }
});

app.post("/deploy", (req, res) => {
  console.log(req.body);
  const deployPort = Math.floor(Math.random() * 10000) + 1;
  console.log(deployPort);

  const { userName, projectName, githubLink, serverPort, env, private } =
    req.body;
  let CloneLink = githubLink;
  if (private) {
    console.log("Private Repo");
    CloneLink = githubLink.replace(
      "git",
      `https://${userName}:${accessTokens[userName]}`
    );
    console.log(CloneLink);
  }
  // Convert the env array to a string format for the script
  const envString = env.map((e) => `${e.key}=${e.value}`).join("\n");

  exec(
    `./auto_deploy_server.sh ${CloneLink} ${projectName} ${serverPort} ${deployPort} ${
      envString ? `"${envString}"` : ""
    }`,
    (error, stdout, stderr) => {
      if (error) {
        console.error(`Error executing script: ${error.message}`);
        return res.status(500).send("Failed to execute script");
      }
      console.log(`Script stdout: ${stdout}`);
      console.error(`Script stderr: ${stderr}`);

      res.send(
        "Script executed successfully with repository: " +
          projectName +
          ".collegestorehub.com"
      );
    }
  );
});

app.get("/branches", async (req, res) => {
  const { username, fullRepoName } = req.query;
  console.log(username, fullRepoName);
  if (!username || !fullRepoName || !accessTokens[username]) {
    return res.status(401).send("Unauthorized");
  }

  try {
    const response = await axios.get(
      `https://api.github.com/repos/${fullRepoName}/branches`,
      {
        headers: {
          Authorization: `Bearer ${accessTokens[username]}`,
        },
      }
    );
    console.log(response.data);
    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send("Failed to fetch branches");
  }
});

app.get("/", (req, res) => {
  res.send("Hello World");
});
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
