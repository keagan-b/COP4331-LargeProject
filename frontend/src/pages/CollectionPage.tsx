import React, { useState, useEffect } from "react";
import { useNavigate, useLocation, useParams } from "react-router-dom";
import Collection from "../components/Collection/Collection";

interface SiblingCollection {
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
  collectionId?: string;
  criteriaValues?: Record<string, string>;
  imageUrl?: string;
}

interface LocationState {
  collection: { _id: string; collectionName: string; };
  category: { _id: string; categoryName: string; };
  siblingCollections: SiblingCollection[];
}

const CollectionPage: React.FC = () => {
  const [criteria, setCriteria] = useState<Criterion[]>([]);
  const [items, setItems] = useState<Item[]>([]);
  const [siblingCollections, setSiblingCollections] = useState<SiblingCollection[]>([]);

  const navigate = useNavigate();
  const location = useLocation();
  const { collectionId } = useParams<{ collectionId: string }>();
  const token = localStorage.getItem("token");

  const state = location.state as LocationState;
  const collection = state?.collection;
  const category = state?.category;

  useEffect(() => {
    if (collection) {
      document.title = `${collection.collectionName} | Collector's Pair-A-Dice`;
    }
  }, [collection]);

  useEffect(() => {
    if (!collection || !category) { navigate("/home"); return; }

    // Sync sibling collections from location state sorted alphabetically
    setSiblingCollections(
      (state?.siblingCollections || []).sort((a: SiblingCollection, b: SiblingCollection) =>
        a.collectionName.localeCompare(b.collectionName)
      )
    );

    const headers = { token: token || "" };

    const fetchCriteriaAndItems = async () => {
      // Fetch criteria
      try {
        const res = await fetch(`/api/categories/criteria?categoryId=${category._id}`, { headers });
        if (res.ok) {
          const data = await res.json();
          setCriteria(data.criteria || []);
        }
      } catch (err) {
        console.error("Failed to fetch criteria:", err);
      }

      // Fetch all items for this category then filter by collectionId and sort
      try {
        const res = await fetch(`/api/categories/items?categoryId=${category._id}`, { headers });
        if (!res.ok) return;
        const data = await res.json();
        const allItems: Item[] = data.items || [];
        setItems(
          allItems
            .filter((item) => item.collectionId?.toString() === collectionId)
            .sort((a: Item, b: Item) => a.itemName.localeCompare(b.itemName))
        );
      } catch (err) {
        console.error("Failed to fetch items:", err);
      }
    };

    fetchCriteriaAndItems();
  }, [collectionId]);

  const handleSiblingSelect = (sibling: SiblingCollection) => {
    navigate(`/collection/${sibling._id}`, {
      state: { collection: sibling, category, siblingCollections },
    });
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

  const handleEditCollection = async (collectionId: string, newName: string): Promise<{ success: boolean; error?: string }> => {
    try {
      const res = await fetch("/api/collections", {
        method: "PATCH",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({ collectionId, collectionName: newName }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to update." };
      setSiblingCollections((prev) => prev.map((c) => c._id === collectionId ? { ...c, collectionName: newName } : c)
        .sort((a: SiblingCollection, b: SiblingCollection) => a.collectionName.localeCompare(b.collectionName))
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
      setSiblingCollections((prev) => prev.filter((c) => c._id !== collectionId));
      if (collectionId === collection._id) {
        navigate(`/category/${category._id}`, { state: { category } });
      }
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
          collectionId,
          criteriaValues,
          imageUrl: imageUrl || null,
        }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to add item." };
      setItems((prev) => [...prev, {
        _id: data._id,
        itemName: data.itemName,
        categoryId: category._id,
        collectionId,
        criteriaValues,
        imageUrl: imageUrl || undefined,
      }].sort((a: Item, b: Item) => a.itemName.localeCompare(b.itemName)));
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
        item._id === itemId ? { ...item, itemName, criteriaValues, imageUrl: imageUrl || undefined } : item
      ).sort((a: Item, b: Item) => a.itemName.localeCompare(b.itemName)));
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
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
  const handleNavigateCategory = () => navigate(`/category/${category._id}`, { state: { category } });
  const handleLogout = () => { localStorage.removeItem("token"); navigate("/login"); };

  if (!collection || !category) return null;

  return (
    <Collection
      categoryName={category.categoryName}
      collectionName={collection.collectionName}
      siblingCollections={siblingCollections}
      criteria={criteria}
      items={items}
      onSiblingSelect={handleSiblingSelect}
      onEditCollection={handleEditCollection}
      onDeleteCollection={handleDeleteCollection}
      onAddItem={handleAddItem}
      onEditItem={handleEditItem}
      onDeleteItem={handleDeleteItem}
      onNavigateHome={handleNavigateHome}
      onNavigateCategory={handleNavigateCategory}
      onLogout={handleLogout}
      onUploadImage={handleUploadImage}
    />
  );
};

export default CollectionPage;
