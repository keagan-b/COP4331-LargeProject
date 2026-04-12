import React, { useState, useRef } from "react";
import "./Signup.css";
import { Link } from "react-router-dom";

const Signup: React.FC = () => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [message, setMessage] = useState("");
  const [isSuccess, setIsSuccess] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const [resendMessage, setResendMessage] = useState("");
  const cooldownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startCooldown = () => {
    setCooldown(3);
    cooldownRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          clearInterval(cooldownRef.current!);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();

    if (cooldown > 0) return;

    if (password !== confirmPassword) {
      setMessage("Passwords do not match");
      setIsSuccess(false);
      return;
    }

    try {
      const res = await fetch("/api/user/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      const data = await res.json();

      if (!res.ok) {
        setMessage(data.error || "Something went wrong. Please try again.");
        setIsSuccess(false);
        startCooldown();
        return;
      }

      setIsSuccess(true);
      setMessage(`Account created! A verification email has been sent to ${email}.`);
      setResendMessage("");
      startCooldown();
    } catch (err) {
      setMessage("Unable to connect to the server. Please try again later.");
      setIsSuccess(false);
      startCooldown();
    }
  };

  const handleResend = async () => {
    if (cooldown > 0) return;

    try {
      const res = await fetch("/api/user/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      startCooldown();

      if (res.status === 409 || res.ok) {
        setResendMessage("Email resent! Check your inbox.");
      } else {
        setResendMessage("Failed to resend. Please try again.");
      }
    } catch {
      setResendMessage("Unable to connect to the server.");
    }
  };

  return (
    <div className="auth-container">
      <h1 className="title">Collector's Pair-A-Dice</h1>

      <div className="auth-box">
        <h2>Sign Up</h2>

        <form onSubmit={handleSignup}>
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <label>Confirm Password</label>
          <input
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
          />
          <button type="submit" disabled={cooldown > 0}>Create Account</button>

          {message && (
            <p className={`message ${isSuccess ? "success" : "error"}`}>
              {message}
            </p>
          )}

          {isSuccess && (
            <p style={{ fontSize: "0.85rem", marginTop: "4px" }}>
              Didn't get an email?{" "}
              {cooldown > 0 ? (
                <span style={{ color: "gray" }}>Send Again</span>
              ) : (
                <span
                  onClick={handleResend}
                  style={{ color: "#007acc", cursor: "pointer", textDecoration: "underline" }}
                >
                  Send Again
                </span>
              )}
            </p>
          )}

          {resendMessage && (
            <p className="message success" style={{ marginTop: "4px" }}>
              {resendMessage}
            </p>
          )}
        </form>

        <p className="switch-text">
          Already have an account? <Link to="/">Log In</Link>
        </p>
      </div>
    </div>
  );
};

export default Signup;
