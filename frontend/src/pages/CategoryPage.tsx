import React, { useState, useEffect } from "react";
import { useNavigate, useLocation, useParams } from "react-router-dom";
import Category from "../components/Category/Category";

interface Collection {
  _id: string;
  collectionName: string;
}

interface Criterion {
  _id: string;
  criteriaName: string;
}

interface Item {
  _id: string;
  itemName: string;
  categoryId: string;
  criteriaValues?: Record<string, string>;
  imageUrl?: string;
}

interface LocationState {
  category: {
    _id: string;
    categoryName: string;
  };
}

const CategoryPage: React.FC = () => {
  const [collections, setCollections] = useState<Collection[]>([]);
  const [criteria, setCriteria] = useState<Criterion[]>([]);
  const [items, setItems] = useState<Item[]>([]);
  const [activeCollectionId, setActiveCollectionId] = useState<string | null>(null);

  const navigate = useNavigate();
  const location = useLocation();
  const { categoryId } = useParams<{ categoryId: string }>();
  const token = localStorage.getItem("token");

  const category = (location.state as LocationState)?.category;

  useEffect(() => {
    if (category) {
      document.title = `${category.categoryName} | Collector's Pair-A-Dice`;
    }
  }, [category]);

  useEffect(() => {
    if (!category) { navigate("/home"); return; }

    const headers = { token: token || "" };

    const init = async () => {
      // Fetch collections
      try {
        const res = await fetch(`/api/collections?categoryId=${categoryId}`, { headers });
        if (res.status === 403 || res.status === 401) { navigate("/login"); return; }
        const data = await res.json();
        setCollections((data.collections || []).sort((a: Collection, b: Collection) =>
          a.collectionName.localeCompare(b.collectionName)
        ));
      } catch (err) {
        console.error("Failed to fetch collections:", err);
      }

      // Fetch criteria
      try {
        const res = await fetch(`/api/categories/criteria?categoryId=${categoryId}`, { headers });
        if (res.ok) {
          const data = await res.json();
          setCriteria(data.criteria || []);
        }
      } catch (err) {
        console.error("Failed to fetch criteria:", err);
      }

      // Fetch items — criteriaValues already embedded on each document
      try {
        const res = await fetch(`/api/categories/items?categoryId=${categoryId}`, { headers });
        if (!res.ok) return;
        const data = await res.json();
        setItems((data.items || []).sort((a: Item, b: Item) =>
          a.itemName.localeCompare(b.itemName)
        ));
      } catch (err) {
        console.error("Failed to fetch items:", err);
      }
    };

    init();
  }, [categoryId]);

  const handleCollectionSelect = (collection: Collection) => {
    setActiveCollectionId(collection._id);
    navigate(`/collection/${collection._id}`, {
      state: { collection, category, siblingCollections: collections },
    });
  };

  const handleAddCollection = async (name: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/collections", {
        method: "POST",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ collectionName: name, categoryId }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to add collection." };
      setCollections((prev) => [...prev, { _id: data.id, collectionName: data.collectionName }]
        .sort((a: Collection, b: Collection) => a.collectionName.localeCompare(b.collectionName))
      );
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleEditCollection = async (collectionId: string, newName: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/collections", {
        method: "PATCH",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ collectionId, collectionName: newName }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to update." };
      setCollections((prev) => prev.map((c) => c._id === collectionId ? { ...c, collectionName: newName } : c)
        .sort((a: Collection, b: Collection) => a.collectionName.localeCompare(b.collectionName))
      );
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleDeleteCollection = async (collectionId: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/collections", {
        method: "DELETE",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ collectionId }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to delete." };
      setCollections((prev) => prev.filter((c) => c._id !== collectionId));
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleAddItem = async (
    itemName: string,
    criteriaValues: Record<string, string>,
    imageUrl?: string
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({
          itemName,
          categoryId: category._id,
          criteriaValues,
          imageUrl: imageUrl || null,
        }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to add item." };

      const newItem: Item = {
        _id: data._id,
        itemName: data.itemName,
        categoryId: category._id,
        criteriaValues,
        imageUrl: imageUrl || undefined,
      };

      setItems((prev) => [...prev, newItem]
        .sort((a: Item, b: Item) => a.itemName.localeCompare(b.itemName))
      );
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleEditItem = async (
    itemId: string,
    itemName: string,
    criteriaValues: Record<string, string>,
    imageUrl?: string
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/items", {
        method: "PATCH",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ itemId, itemName, criteriaValues, imageUrl: imageUrl || null }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to update item." };
      setItems((prev) => prev.map((item) =>
        item._id === itemId ? { ...item, itemName, criteriaValues, imageUrl } : item
      ).sort((a: Item, b: Item) => a.itemName.localeCompare(b.itemName)));
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleUploadImage = async (file: File): Promise<{ url: string; error?: string }> => {
    try {
      const formData = new FormData();
      formData.append("image", file);
      const res = await fetch("/api/upload-image", {
        method: "POST",
        headers: { token: token || "" },
        body: formData,
      });
      const data = await res.json();
      if (!res.ok) return { url: "", error: data.error };
      return { url: data.url };
    } catch {
      return { url: "", error: "Upload failed." };
    }
  };

  const handleDeleteItem = async (itemId: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/items", {
        method: "DELETE",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ itemId }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to delete item." };
      setItems((prev) => prev.filter((item) => item._id !== itemId));
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleNavigateHome = () => navigate("/home");
  const handleLogout = () => { localStorage.removeItem("token"); navigate("/login"); };

  if (!category) return null;

  return (
    <Category
      categoryName={category.categoryName}
      collections={collections}
      criteria={criteria}
      items={items}
      activeCollectionId={activeCollectionId}
      onCollectionSelect={handleCollectionSelect}
      onAddCollection={handleAddCollection}
      onEditCollection={handleEditCollection}
      onDeleteCollection={handleDeleteCollection}
      onAddItem={handleAddItem}
      onEditItem={handleEditItem}
      onDeleteItem={handleDeleteItem}
      onNavigateHome={handleNavigateHome}
      onLogout={handleLogout}
      onUploadImage={handleUploadImage}
    />
  );
};

export default CategoryPage;
