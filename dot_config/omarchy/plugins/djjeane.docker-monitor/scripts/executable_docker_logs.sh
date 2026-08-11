#!/bin/bash
exec docker logs --tail "${2:-100}" --timestamps "$1" 2>&1
