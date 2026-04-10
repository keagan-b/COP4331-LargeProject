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
}

interface LocationState {
  collection: {
    _id: string;
    collectionName: string;
  };
  category: {
    _id: string;
    categoryName: string;
  };
  siblingCollections: SiblingCollection[];
}

const CollectionPage: React.FC = () => {
  const [criteria, setCriteria] = useState<Criterion[]>([]);
  const [items, setItems] = useState<Item[]>([]);

  const navigate = useNavigate();
  const location = useLocation();
  const { collectionId } = useParams<{ collectionId: string }>();
  const token = localStorage.getItem("token");

  const state = location.state as LocationState;
  const collection = state?.collection;
  const category = state?.category;
  const siblingCollections = state?.siblingCollections || [];

  useEffect(() => {
    if (!collection || !category) { navigate("/"); return; }

    const headers = { token: token || "" };

    const fetchCriteriaAndItems = async () => {
      // Step 1: fetch criteria using the correct endpoint
      try {
        const res = await fetch(`/api/categories/criteria?categoryId=${category._id}`, { headers });
        if (res.ok) {
          const data = await res.json();
          setCriteria(data.criteria || []);
        }
      } catch (err) {
        console.error("Failed to fetch criteria:", err);
      }

      // Step 2: fetch items for this category then filter by collectionId
      // Items store collectionId as a field so we filter client-side
      try {
        const res = await fetch(`/api/categories/items?categoryId=${category._id}`, { headers });
        if (!res.ok) return;
        const data = await res.json();
        const allItems: Item[] = data.items || [];
        // Only show items belonging to this specific collection
        setItems(allItems.filter((item) => item.collectionId === collectionId));
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

  const handleAddItem = async (
    itemName: string,
    criteriaValues: Record<string, string>
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      // Post to /api/items with collectionId and criteriaValues embedded
      const res = await fetch("/api/items", {
        method: "POST",
        headers: { "Content-Type": "application/json", token: token || "" },
        body: JSON.stringify({
          itemName,
          categoryId: category._id,
          collectionId,
          criteriaValues,
        }),
      });
      const data = await res.json();
      if (!res.ok) return { success: false, error: data.error || "Failed to add item." };

      const newItem: Item = {
        _id: data._id,
        itemName: data.itemName,
        categoryId: category._id,
        collectionId,
        criteriaValues,
      };

      setItems((prev) => [...prev, newItem]);
      return { success: true };
    } catch {
      return { success: false, error: "Unable to connect to server." };
    }
  };

  const handleNavigateHome = () => navigate("/");

  const handleNavigateCategory = () =>
    navigate(`/category/${category._id}`, { state: { category } });

  const handleLogout = () => {
    localStorage.removeItem("token");
    navigate("/login");
  };

  if (!collection || !category) return null;

  return (
    <Collection
      categoryName={category.categoryName}
      collectionName={collection.collectionName}
      siblingCollections={siblingCollections}
      criteria={criteria}
      items={items}
      onSiblingSelect={handleSiblingSelect}
      onAddItem={handleAddItem}
      onNavigateHome={handleNavigateHome}
      onNavigateCategory={handleNavigateCategory}
      onLogout={handleLogout}
    />
  );
};

export default CollectionPage;