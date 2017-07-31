# COMPANY-INFO Scraper
## Requirements
### Storing files in cloud
The google cloud storage will contain only the last version of cnpj details named with the cnpj.
all versions will be published by pub/sub.  

### API details
 - **get_cnpj_info**  
   - **Overview**: This function gets the cnpj info
   - **input**:  cnpj_number (with or without formatting)
   - **output**:  
      {:ok,    cnpj_info}  
      {:error, reason}  
   - **Details**:  
   This function returns the updated cnpj.json file from the bucket.
   If the file is not encountered in the bucket the update_cnpj_info function is called and then the cnpj.json is returned.
   the json file returned will contain company information and company's partners information

 - **update_cnpj_info**  
   - **Overview**: This function does the following:
     - downloads the main html from the receita website and sends it to pub/sub.  
     - parses the main html to json.
     - downloads the company partners html info and sends it to pub/sub.
     - parses the company partners html and addes it to main json.
     - sends the complete json to pub/sub.

   - **input**:  cnpj
   - **output**:  
       {:ok}  
       {:error, reason}
   - **Details**
    This function may be called in two situations:  
    **a.** From get_cnpj_info (when file does not exist in storage)  
    **b.** Every once a while this function will be automatically activated in order to update the file in storage.  
