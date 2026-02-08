import { dev } from "elm-pages/vite/plugin.mjs";

export default {
  plugins: [dev()],
  build: {
    rollupOptions: {
      external: ["/index"],
      input: {
        app: "./app/Route/Index.elm",
      },
    },
  },
};
