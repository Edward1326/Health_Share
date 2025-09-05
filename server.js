require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const { Client, PrivateKey } = require("@hiveio/dhive");
const CryptoJS = require("crypto-js");

const app = express();

// Security middleware
app.use(helmet());
app.use(
  cors({
    origin:
      process.env.NODE_ENV === "production"
        ? ["https://your-app-domain.com"]
        : ["http://localhost:3000", "http://127.0.0.1:3000"],
  })
);
app.use(express.json({ limit: "10mb" }));

// Hive client setup
const client = new Client([
  "https://api.hive.blog",
  "https://api.hivekings.com",
  "https://anyx.io",
]);

const username = process.env.HIVE_USERNAME;
const privateKey = PrivateKey.fromString(process.env.HIVE_POSTING_KEY);
const appSalt = process.env.APP_SALT;

// Security: Hash user IDs for privacy
function hashUserId(userId) {
  return CryptoJS.SHA256(userId + appSalt).toString();
}

// Security: Input validation
function validateLogData(req, res, next) {
  const { fileHash, userId } = req.body;

  if (!fileHash || !userId) {
    return res.status(400).json({
      success: false,
      error: "Missing required fields",
    });
  }

  if (fileHash.length !== 64) {
    // SHA-256 is 64 chars
    return res.status(400).json({
      success: false,
      error: "Invalid file hash format",
    });
  }

  next();
}

// Main logging function
async function logToHive(logData) {
  try {
    const operation = [
      "custom_json",
      {
        required_auths: [],
        required_posting_auths: [username],
        id: "medical_records_audit",
        json: JSON.stringify({
          ...logData,
          app_version: "1.0.0",
          logged_at: new Date().toISOString(),
        }),
      },
    ];

    const result = await client.broadcast.sendOperations(
      [operation],
      privateKey
    );
    return { success: true, transactionId: result.id };
  } catch (error) {
    console.error("Hive logging failed:", error);
    return { success: false, error: error.message };
  }
}

// API Endpoints

// Test endpoint
app.get("/api/test", (req, res) => {
  res.json({
    success: true,
    message: "Hive API server is running",
    username: username,
  });
});

// Log file upload
app.post("/api/log-upload", validateLogData, async (req, res) => {
  try {
    const { fileHash, userId, ipfsCid, fileType, recipientsCount } = req.body;

    const result = await logToHive({
      action: "upload",
      file_hash: fileHash,
      user_id: hashUserId(userId),
      ipfs_cid: ipfsCid || "unknown",
      file_type: fileType || "unknown",
      recipients_count: recipientsCount || 0,
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Server error during upload logging",
    });
  }
});

// Log file access
app.post("/api/log-access", validateLogData, async (req, res) => {
  try {
    const { fileHash, userId, fileId } = req.body;

    const result = await logToHive({
      action: "access",
      file_hash: fileHash,
      user_id: hashUserId(userId),
      file_id: fileId || "unknown",
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Server error during access logging",
    });
  }
});

// Log access revocation
app.post("/api/log-revocation", validateLogData, async (req, res) => {
  try {
    const { fileHash, userId, fileId } = req.body;

    const result = await logToHive({
      action: "revoke",
      file_hash: fileHash,
      user_id: hashUserId(userId),
      file_id: fileId || "unknown",
      method: "crypto_erasure",
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Server error during revocation logging",
    });
  }
});

// Get audit history
app.get("/api/audit-history/:fileHash", async (req, res) => {
  try {
    const { fileHash } = req.params;

    if (fileHash.length !== 64) {
      return res.status(400).json({
        success: false,
        error: "Invalid file hash format",
      });
    }

    const history = await client.database.getAccountHistory(username, -1, 100);

    const auditLogs = history
      .filter(
        ([, op]) =>
          op[0] === "custom_json" && op[1].id === "medical_records_audit"
      )
      .map(([, op]) => {
        try {
          return JSON.parse(op[1].json);
        } catch (e) {
          return null;
        }
      })
      .filter((log) => log && log.file_hash === fileHash)
      .sort((a, b) => new Date(b.logged_at) - new Date(a.logged_at));

    res.json({ success: true, logs: auditLogs });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Server error getting audit history",
    });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Hive API server running on port ${PORT}`);
  console.log(`Username: ${username}`);
});
