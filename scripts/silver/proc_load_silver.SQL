/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

EXEC silver.load_silver

CREATE OR ALTER PROCEDURE silver.load_silver AS

    BEGIN 
		DECLARE @start_time DATETIME , @end_time DATETIME , @batch_start_time DATETIME , @batch_end_time DATETIME ;

	BEGIN TRY 
    
		SET @batch_start_time = GETDATE();

		PRINT '==============================================' ;

		PRINT'Loading Silver Layer' ;

		PRINT '==============================================' ;

		PRINT '----------------------------------------------' ;

		PRINT'Loading CRM Tables' ;

		PRINT '----------------------------------------------' ;

		SET @start_time = GETDATE();


PRINT '>> Truncating Table: silver.crm_cust_info';


TRUNCATE TABLE silver.crm_cust_info

PRINT '>> Inserting Data Into: silver.crm_cust_info';

		INSERT INTO silver.crm_cust_info 
			(cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date)

	select cst_id,cst_key,

	cst_firstname AS cst_firstname,

	TRIM (cst_lastname) AS cst_lastname,



	case when upper(trim(cst_marital_status)) = 'M' then 'Married'
		  when  upper(trim(cst_marital_status)) = 'S' then 'Single'
		  else 'n/a'
		  end cst_marital_status,

	case when upper(trim(cst_gndr)) = 'F' then 'Female'
		 when upper(trim(cst_gndr)) = 'M' then 'Male'
		 else 'n/a'
	end  cst_gndr,

	cst_create_date

	from (


	SELECT *,

	ROW_NUMBER() over ( partition by cst_id order by cst_create_date DESC ) as flag_last

	FROM bronze.crm_cust_info ) t

	where flag_last = 1 and cst_id IS NOT NULL 

    SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;

		SET @start_time = GETDATE()


 PRINT '>> Truncating Table: silver.crm_prd_info';


TRUNCATE TABLE silver.crm_prd_info

PRINT '>> Inserting Data Into: silver.crm_prd_info';



INSERT INTO silver.crm_prd_info(prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt )
            

SELECT prd_id,
          
      

      REPLACE ( substring(prd_key,1,5) , '-' , '_' ) AS cat_id,

      substring( prd_key,7,len(prd_key)) AS prd_key,


       prd_nm,

       ISNULL (prd_cost , 0) AS prd_cost,
       CASE UPPER(TRIM(prd_line))
       WHEN  'M' THEN 'Mountain'
       WHEN 'R' THEN 'Road'
       WHEN 'S' THEN 'other Sales'
       WHEN 'T' THEN 'Touring'
       ELSE 'n/a' 
       END AS prd_line, 

       CAST (prd_start_dt AS DATE) AS prd_start_dt,
       
       CAST (LEAD(prd_start_dt) OVER ( PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS DATE) AS prd_end_dt

 

FROM bronze.crm_prd_info

SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;

		SET @start_time = GETDATE()


PRINT '>> Truncating Table: silver.crm_sales_details';

TRUNCATE TABLE silver.crm_sales_details

PRINT '>> Inserting Data Into: silver.crm_sales_details';

INSERT INTO silver.crm_sales_details(
           sls_ord_num,
           sls_prd_key,
           sls_cust_id,
           sls_order_dt,
           sls_ship_dt,
           sls_due_dt,
           sls_sales,
           sls_quantity,
           sls_price

           )


select sls_ord_num,
       sls_prd_key,
       sls_cust_id,
       
       CASE WHEN sls_ship_dt = 0 or LEN(sls_ship_dt) != 8 THEN NULL
            ELSE CAST( CAST (sls_ship_dt AS VARCHAR) AS DATE)
       END AS sls_order_dt,

        CASE WHEN sls_ship_dt = 0 or LEN(sls_ship_dt) != 8 THEN NULL
            ELSE CAST( CAST (sls_ship_dt AS VARCHAR) AS DATE)
       END AS sls_ship_dt,

       CASE WHEN sls_due_dt = 0 or LEN(sls_due_dt) != 8 THEN NULL
            ELSE CAST( CAST (sls_due_dt AS VARCHAR) AS DATE)
       END AS sls_due_dt,
  
    CASE WHEN sls_sales IS NULL OR  sls_sales <= 0 OR  sls_sales != sls_quantity * ABS(sls_price) 
         THEN sls_quantity * ABS ( (sls_price))
         ELSE sls_sales
    END AS sls_sales,

    sls_quantity,
    
    CASE WHEN sls_price is null or sls_price <= 0
          THEN sls_sales / NULLIF ( sls_quantity , 0 )
        ELSE sls_price

    END AS sls_price

    

    FROM bronze.crm_sales_details


 /* Cleaning up part where sls_sales != sls_quantity * sls_price

  or  sls_sales is null or sls_quantity is null or sls_price is null 

  or  sls_sales <=0 or sls_quantity <=0 or  sls_price <=0

  order by sls_sales , sls_quantity , sls_price

  -- with that we are done cleaning up the sales details */


  SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;

		PRINT '----------------------------------------------' ;

		PRINT'Loading ERP Tables' ;

		PRINT '----------------------------------------------' ;

SET @start_time = GETDATE()


PRINT '>> Truncating Table: silver.erp_cust_az12';

TRUNCATE TABLE silver.erp_cust_az12

PRINT '>> Inserting Data Into: silver.silver.erp_cust_az12';
  
  INSERT INTO silver.erp_cust_az12 (cid,bdate,gen)

  SELECT 

  CASE WHEN cid like 'NAS%' THEN SUBSTRING (cid, 4 , len(cid))
       else cid
  END AS cid,

  CASE WHEN bdate > GETDATE() THEN NULL
       ELSE bdate
  END AS bdate, -- Set future birthdates to NULL

 CASE  WHEN UPPER(TRIM(gen)) IN ('M' , 'MALE') THEN 'Male'
       WHEN UPPER(TRIM(gen)) IN ('F' , 'FEMALE') THEN 'Female'
                      ELSE 'n/a'
                      
                       END AS gen --Normalise gender values and handle unknown cases

                       from bronze.erp_cust_az12 

                       SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;

		SET @start_time = GETDATE()

PRINT '>> Truncating Table: silver.erp_loc_a101';

TRUNCATE TABLE silver.erp_loc_a101

PRINT '>> Inserting Data Into: silver.erp_loc_a101';

 INSERT INTO silver.erp_loc_a101

  (cid,cntry)

    select replace(cid, '-' ,'') as cid,
  CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
     WHEN TRIM(cntry) IN ( 'US' , 'USA') THEN 'United States'
     WHEN TRIM(cntry) = '' OR cntry IS Null THEN 'n/a'
     ELSE TRIM(cntry)
END as cntry

  from bronze.erp_loc_a101 

  SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;

		SET @start_time = GETDATE()


PRINT '>> Truncating Table: silver.erp_px_cat_g1v2 ';


TRUNCATE TABLE silver.erp_px_cat_g1v2 

PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2 ';


INSERT INTO silver.erp_px_cat_g1v2 (id , cat, subcat, maintenance)
  
SELECT id, cat, subcat , maintenance

FROM [DataWarehouse].[bronze].[erp_px_cat_g1v2] 

SET @end_time = GETDATE();

-- without truncating we will be adding the duplicates 	SET @end_time = GETDATE();

		PRINT '>> Load Duration : ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '>> -----------' ;
	
		SET @batch_end_time = GETDATE();

		PRINT '============================================' ;

		PRINT 'Loading Silver Layer is Completed'
	

		PRINT ' - Total Load Duration : ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR ) + 'seconds' ;
		PRINT '============================================' ;
	

		   END TRY 
			BEGIN CATCH
			PRINT '=========================================='
			PRINT 'ERROR OCCURED DURING LOADING Silver LAYER'
			PRINT 'Error Message' + ERROR_MESSAGE();
			PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
			PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
			PRINT '=========================================='
		END CATCH

END 





       


