# Start from the Nginx image based on Alpine
FROM nginx:alpine

# Remove the default index.html
RUN rm /usr/share/nginx/html/index.html

# Copy the frontend application source to the Nginx HTML directory
COPY src /usr/share/nginx/html

# Copy the startup script into the container
COPY init.sh /usr/local/bin/init.sh

# Make the script executable
RUN chmod +x /usr/local/bin/init.sh

# Expose port 80
EXPOSE 80

# Run the script to set up the server URL and start Nginx
CMD ["/usr/local/bin/init.sh"]
