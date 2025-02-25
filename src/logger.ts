import winston from "winston";

import { CUMARU_LOG_LEVEL } from "./config";

const logger = winston.createLogger({
  level: CUMARU_LOG_LEVEL,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ level, message, timestamp, ...rest }) => {
          const metadata =
            Object.keys(rest).length > 0
              ? `\n${JSON.stringify(rest, null, 2)}`
              : "";
          return `${timestamp} [${level}]: ${message}${metadata}`;
        })
      ),
    }),
    // new winston.transports.File({ filename: "error.log", level: "error" }),
    // new winston.transports.File({ filename: "combined.log" }),
  ],
});

export default logger;
