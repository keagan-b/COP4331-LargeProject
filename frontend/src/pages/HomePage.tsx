import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import Home from "../components/Home/Home";

interface Category {
  _id: string;
  categoryName: string;
}

const HomePage: React.FC = () => {
  const [categories, setCategories] = useState<Category[]>([]);
  const [categoryThumbnails, setCategoryThumbnails] = useState<Record<string, string | null>>({});
  const navigate = useNavigate();
  const token = localStorage.getItem("token");

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await fetch("/api/categories", {
          headers: { token: token || "" },
        });
        if (res.status === 403 || res.status === 401) {
          navigate("/");
          return;
        }
        const data = await res.json();
        const sorted: Category[] = (data.userCategories || []).sort(
          (a: Category, b: Category) => a.categoryName.localeCompare(b.categoryName)
        );
        setCategories(sorted);

        // Fetch first item thumbnail for each of the first 10 categories in parallel
        const first10 = sorted.slice(0, 10);
        const thumbnailEntries = await Promise.all(
          first10.map(async (cat) => {
            try {
              const itemsRes = await fetch(
                `/api/categories/items?categoryId=${cat._id}`,
                { headers: { token: token || "" } }
              );
              if (!itemsRes.ok) return [cat._id, null] as [string, null];
              const itemsData = await itemsRes.json();
              const firstItem = (itemsData.items || [])[0];
              return [cat._id, firstItem?.imageUrl ?? null] as [string, string | null];
            } catch {
              return [cat._id, null] as [string, null];
            }
          })
        );
        setCategoryThumbnails(Object.fromEntries(thumbnailEntries));
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
      const catRes = await fetch("/api/categories", {
        method: "POST",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ categoryName: name }),
      });
      const catData = await catRes.json();
      if (!catRes.ok) return { success: false, error: catData.error || "Failed to add category." };

      const newCategoryId = catData._id;
      for (const criteriaName of criteria) {
        try {
          await fetch("/api/categories/criteria", {
            method: "POST",
            headers: { "Content-Type": "application/json", token: token || "" },
            body: JSON.stringify({ criteriaName, categoryId: newCategoryId }),
          });
        } catch (err) {
          console.error(`Failed to add criterion "${criteriaName}":`, err);
        }
      }

      setCategories((prev) =>
        [...prev, { _id: newCategoryId, categoryName: catData.categoryName }].sort(
          (a, b) => a.categoryName.localeCompare(b.categoryName)
        )
      );
      // New category has no items yet
      setCategoryThumbnails((prev) => ({ ...prev, [newCategoryId]: null }));
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleLogout = () => {
    localStorage.removeItem("token");
    navigate("/");
  };

  const handleEditCategory = async (
    categoryId: string,
    name: string,
    criteria: string[]
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/categories", {
        method: "PATCH",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ categoryId, categoryName: name }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error };

      const existing = await fetch(`/api/categories/criteria?categoryId=${categoryId}`, {
        headers: { token: token || "" },
      });
      const existingData = await existing.json();
      const existingCriteria: { _id: string; criteriaName: string }[] = existingData.criteria || [];

      for (const ec of existingCriteria) {
        if (!criteria.includes(ec.criteriaName)) {
          await fetch("/api/categories/criteria", {
            method: "DELETE",
            headers: { "Content-Type": "application/json", token: token || "" },
            body: JSON.stringify({ criteriaId: ec._id }),
          });
        }
      }
      for (const c of criteria) {
        if (!existingCriteria.find((ec) => ec.criteriaName === c)) {
          await fetch("/api/categories/criteria", {
            method: "POST",
            headers: { "Content-Type": "application/json", token: token || "" },
            body: JSON.stringify({ criteriaName: c, categoryId }),
          });
        }
      }

      setCategories((prev) =>
        prev.map((cat) => (cat._id === categoryId ? { ...cat, categoryName: name } : cat))
          .sort((a, b) => a.categoryName.localeCompare(b.categoryName))
      );
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleDeleteCategory = async (categoryId: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/categories", {
        method: "DELETE",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ categoryId }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error };
      setCategories((prev) => prev.filter((cat) => cat._id !== categoryId));
      setCategoryThumbnails((prev) => {
        const next = { ...prev };
        delete next[categoryId];
        return next;
      });
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const getCategoryCriteria = async (categoryId: string): Promise<string[]> => {
    try {
      const res = await fetch(`/api/categories/criteria?categoryId=${categoryId}`, {
        headers: { token: token || "" },
      });
      if (!res.ok) return [];
      const data = await res.json();
      return (data.criteria || []).map((c: { criteriaName: string }) => c.criteriaName);
    } catch {
      return [];
    }
  };

  return (
    <Home
      categories={categories}
      categoryThumbnails={categoryThumbnails}
      onCategorySelect={handleCategorySelect}
      onAddCategory={handleAddCategory}
      onLogout={handleLogout}
      onEditCategory={handleEditCategory}
      onDeleteCategory={handleDeleteCategory}
      getCategoryCriteria={getCategoryCriteria}
    />
  );
};

export default HomePage;
