const express = require("express");
const mongoose = require("mongoose");

const app = express();
app.use(express.json());

const MONGO_URI = process.env.MONGO_URI || "mongodb://localhost:27017/todos";

mongoose
    .connect(MONGO_URI)
    .then(() => console.log("MongoDB connected"))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });

const Todo = mongoose.model(
    "Todo",
    new mongoose.Schema({
        title: { type: String, required: true },
        done: { type: Boolean, default: false },
    }),
);

app.get("/health", (req, res) => res.json({ status: "ok" }));
app.get("/todos", async (req, res) => res.json(await Todo.find()));
app.post("/todos", async (req, res) => {
    const todo = await Todo.create({ title: req.body.title });
    res.status(201).json(todo);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
