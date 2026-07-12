import { createHashRouter } from "react-router-dom";
import { App } from "./app";

export const router = createHashRouter([
  {
    path: "/",
    Component: App,
  },
]);
