post:
	@read -p "What is your post title? " title; \
	kebab_title=$$(echo "$$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9-]//g'); \
	hugo new content content/posts/$$kebab_title.md
