#!/usr/bin/env node
import fs from 'node:fs';

const [reportPath, schemaPath = '.harness/schemas/delivery-report.schema.json'] = process.argv.slice(2);

function fail(message) {
  console.error(`[delivery-validate] ${message}`);
  process.exit(1);
}

function readJson(file, label) {
  if (!file) fail(`missing ${label} path`);
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`${label} is not valid JSON: ${file}: ${error.message}`);
  }
}

function typeOf(value) {
  if (Array.isArray(value)) return 'array';
  if (value === null) return 'null';
  return typeof value;
}

function validateNode(value, schema, path, errors) {
  if (!schema || typeof schema !== 'object') return;

  if (schema.type && typeOf(value) !== schema.type) {
    errors.push(`${path} must be ${schema.type}, got ${typeOf(value)}`);
    return;
  }

  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(`${path} must be one of ${schema.enum.join(', ')}`);
  }

  if (schema.type === 'object') {
    const required = Array.isArray(schema.required) ? schema.required : [];
    for (const key of required) {
      if (!Object.prototype.hasOwnProperty.call(value, key)) {
        errors.push(`${path}.${key} is required`);
      }
    }

    const properties = schema.properties || {};
    for (const [key, item] of Object.entries(value)) {
      if (!Object.prototype.hasOwnProperty.call(properties, key)) {
        if (schema.additionalProperties === false) {
          errors.push(`${path}.${key} is not allowed`);
        }
        continue;
      }
      validateNode(item, properties[key], `${path}.${key}`, errors);
    }
  }

  if (schema.type === 'array') {
    const itemSchema = schema.items || {};
    value.forEach((item, index) => validateNode(item, itemSchema, `${path}[${index}]`, errors));
  }
}

const report = readJson(reportPath, 'delivery report');
const schema = readJson(schemaPath, 'delivery schema');
const errors = [];

validateNode(report, schema, '$', errors);

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`[delivery-validate] ${error}`);
  }
  process.exit(1);
}

console.log(`[delivery-validate] OK ${reportPath}`);
