import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Home from "../components/Home/Home";

interface Category {
  _id: string;
  categoryName: string;
}

const HomePage: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const navigate = useNavigate();
  const token = localStorage.getItem("token");

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await fetch("/api/categories", {
          headers: { token: token || "" },
        });
        if (res.status === 403 || res.status === 401) {
          navigate("/login");
          return;
        }
        const data = await res.json();
        setCategories(data.userCategories || []);
      } catch (err) {
        console.error("Failed to fetch categories:", err);
      }
    };

    fetchCategories();
  }, []);

  const handleCategorySelect = (category: Category) => {
    navigate(`/category/${category._id}`, { state: { category } });
  };

  const handleAddCategory = async (
    name: string,
    criteria: string[]
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      // Step 1: Create the category
      const catRes = await fetch("/api/categories", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          token: token || "",
        },
        body: JSON.stringify({ categoryName: name }),
      });

      const catData = await catRes.json();

      if (!catRes.ok) {
        return { success: false, error: catData.error || "Failed to add category." };
      }

      const newCategoryId = catData._id;

      // Step 2: Post each criterion linked to the new category
      for (const criteriaName of criteria) {
        try {
          await fetch("/api/categories/criteria", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              token: token || "",
            },
            body: JSON.stringify({
              criteriaName,
              categoryId: newCategoryId,
            }),
          });
        } catch (err) {
          console.error(`Failed to add criterion "${criteriaName}":`, err);
        }
      }

      // Append new category to sidebar
      setCategories((prev) => [
        ...prev,
        { _id: newCategoryId, categoryName: catData.categoryName },
      ]);

      return { success: true };
    } catch (err) {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleLogout = () => {
    localStorage.removeItem("token");
    navigate("/login");
  };

  return (
    <Home
      categories={categories}
      onCategorySelect={handleCategorySelect}
      onAddCategory={handleAddCategory}
      onLogout={handleLogout}
    />
  );
};

export default HomePage;
