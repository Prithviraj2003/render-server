// const express = require('express');
// const session = require('express-session');
// const passport = require('passport');
// const GitHubStrategy = require('passport-github2').Strategy;
// const axios = require('axios');
// require('dotenv').config();

// const app = express();
// const port = process.env.PORT || 5000;

// // Session middleware
// app.use(session({
//   secret: process.env.SESSION_SECRET,
//   resave: false,
//   saveUninitialized: true
// }));

// // Initialize passport
// app.use(passport.initialize());
// app.use(passport.session());

// // GitHub OAuth Strategy
// passport.use(new GitHubStrategy({
//   clientID: process.env.GITHUB_CLIENT_ID,
//   clientSecret: process.env.GITHUB_CLIENT_SECRET,
//   callbackURL: "/auth/github/callback"
// }, (accessToken, refreshToken, profile, done) => {
//   // Save access token and profile info in session
//   return done(null, { profile, accessToken });
// }));

// passport.serializeUser((user, done) => {
//   done(null, user);
// });

// passport.deserializeUser((obj, done) => {
//   done(null, obj);
// });

// // GitHub login route
// app.get('/auth/github', passport.authenticate('github', { scope: ['user', 'repo'] }));

// // GitHub callback route
// app.get('/auth/github/callback',
//   passport.authenticate('github', { failureRedirect: '/' }),
//   (req, res) => {
//     res.redirect('/repos');
//   });

// // Fetch user's GitHub repositories
// app.get('/repos', (req, res) => {
//   if (!req.isAuthenticated()) {
//     return res.redirect('/auth/github');
//   }

//   const accessToken = req.user.accessToken;

//   // Fetch user repositories from GitHub API
//   axios.get('https://api.github.com/user/repos', {
//     headers: {
//       Authorization: `token ${accessToken}`
//     }
//   })
//   .then(response => {
//     const repos = response.data;
//     res.json(repos);
//   })
//   .catch(error => {
//     console.error('Error fetching repos:', error);
//     res.status(500).json({ error: 'Failed to fetch repositories' });
//   });
// });

// // Start server
// app.listen(port, () => {
//   console.log(`Server running on http://localhost:${port}`);
// });

// server.js
const express = require("express");
const axios = require("axios");
const cors = require("cors");
const app = express();
const port = 5000;

const clientID = "Iv23liZu0vG8Ms2Pcw1n"; // Add your GitHub Client ID
const clientSecret = "1510846215469f6768cb1666dbca569ec2daa369";

app.use(cors()); // Enable CORS for cross-origin requests
app.use(express.json());

const accessTokens = {};

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
        client_id: clientID,
        client_secret: clientSecret,
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
        visibility: 'all', // Include private repos
      }
    });

    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send("Failed to fetch repositories");
  }
});

app.post("/deploy",(req,res)=>{
  console.log(req.body);
  const deployPort=9000
  const {projectName,githubLink,serverPort}=req.body;
  // exec(`./script.sh ${githubLink} ${projectName} ${serverPort} ${deployPort}`, (error, stdout, stderr) => {
  //   if (error) {
  //     console.error(`Error executing script: ${error.message}`);
  //     return res.status(500).send('Failed to execute script');
  //   }
  //   console.log(`Script stdout: ${stdout}`);
  //   console.error(`Script stderr: ${stderr}`);

  //   res.send('Script executed successfully with repository: ' + projectName+'.collegestorehub.com');
  // });

  
})

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
