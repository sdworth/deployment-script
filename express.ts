import express from "express";
import { backend, checkin } from "./index";
import * as process from "process";

const app = express();
const port = process.env.PORT || 3000;

app.get( "/", async ( req, res ) => {
  const resp = await backend();
  const data = JSON.parse(resp.body);
  res.status = resp.statusCode;
  res.json(data);
});

app.post( "/checkin", ( req, res ) => {
  checkin();
  res.json({message: "Successfully checked in a patient."});
});

app.listen( port, () => {
  console.log(`server started at http://localhost:${ port }`);
});
