#!/bin/bash

echo "=== Deploying iCare Backend to Vercel ==="

# Navigate to backend directory
cd icare-backend || exit 1

# Deploy to Vercel
echo "Deploying backend..."
vercel --prod --yes

echo "=== Backend Deployment Complete ==="
