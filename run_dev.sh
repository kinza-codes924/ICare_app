#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Starting iCare Development Servers${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if we're in a terminal that supports gnome-terminal, xterm, or other
if command -v gnome-terminal &> /dev/null; then
    echo -e "${GREEN}Opening Backend in new terminal...${NC}"
    gnome-terminal -- bash -c "cd Icare_backend-main && echo 'Starting Backend Server...' && npm start; exec bash"
    
    sleep 2
    
    echo -e "${GREEN}Opening Frontend in new terminal...${NC}"
    gnome-terminal -- bash -c "echo 'Starting Flutter Frontend...' && flutter run -d chrome --web-port 8080; exec bash"
    
elif command -v xterm &> /dev/null; then
    echo -e "${GREEN}Opening Backend in new terminal...${NC}"
    xterm -e "cd Icare_backend-main && echo 'Starting Backend Server...' && npm start; bash" &
    
    sleep 2
    
    echo -e "${GREEN}Opening Frontend in new terminal...${NC}"
    xterm -e "echo 'Starting Flutter Frontend...' && flutter run -d chrome --web-port 8080; bash" &
    
elif command -v konsole &> /dev/null; then
    echo -e "${GREEN}Opening Backend in new terminal...${NC}"
    konsole -e bash -c "cd Icare_backend-main && echo 'Starting Backend Server...' && npm start; exec bash" &
    
    sleep 2
    
    echo -e "${GREEN}Opening Frontend in new terminal...${NC}"
    konsole -e bash -c "echo 'Starting Flutter Frontend...' && flutter run -d chrome --web-port 8080; exec bash" &
    
else
    echo -e "${YELLOW}No supported terminal emulator found. Running in current terminal...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop both servers${NC}\n"
    
    # Fallback to running in same terminal
    cleanup() {
        echo -e "\n${YELLOW}Shutting down servers...${NC}"
        kill 0
        exit
    }
    
    trap cleanup SIGINT SIGTERM
    
    cd Icare_backend-main
    npm start &
    BACKEND_PID=$!
    cd ..
    
    sleep 3
    
    flutter run -d chrome --web-port 8080 &
    FRONTEND_PID=$!
    
    wait
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Backend will run on: http://localhost:5000${NC}"
echo -e "${GREEN}✓ Frontend will run on: http://localhost:8080${NC}"
echo -e "${BLUE}========================================${NC}"
