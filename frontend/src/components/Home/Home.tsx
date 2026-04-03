import React from "react";
import { useNavigate } from "react-router-dom";
import "./Home.css";

const Home: React.FC = () => {
  const navigate = useNavigate();

  const handleLogout = () => {
    localStorage.removeItem("token");
    navigate("/login");
  };

  return (
    <div className="home-container">
      <header className="home-header">
        <h1 className="title">Collecting Paradise</h1>
        <button className="logout-btn" onClick={handleLogout}>
          Log Out
        </button>
      </header>

      <main className="home-main">
        
        <p>You are now logged in.</p>
      </main>
    </div>
  );
};

export default Home;