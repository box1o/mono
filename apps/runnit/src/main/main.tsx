import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router-dom";
import { Providers } from "./providers";
import { router } from "./router";
import "@/shared/styles/index.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Runnit root element was not found");
}

createRoot(root).render(
  <StrictMode>
    <Providers>
      <RouterProvider router={router} />
    </Providers>
  </StrictMode>,
);
