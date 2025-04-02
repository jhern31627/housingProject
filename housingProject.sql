USE housingProject

SELECT * INTO housingWork 
FROM housing

select * 
FROM housingWork

-------------------------------------------------------------------------------------------------------------------------
---1. Standardize date 
SELECT 
	CONVERT(date, SaleDate) as ymd
FROM housingWork


ALTER TABLE housingWork
ADD salesDateConvert DATE

UPDATE housingWork
SET salesDateConvert = CONVERT(date, SaleDate)

select * 
FROM housingWork


-------------------------------------------------------------------------------------------------------------------------
---2. Property Address Split
SELECT 
	SUBSTRING(propertyAddress, 1, CHARINDEX(',' , PropertyAddress) -1 ) AS addressPropertySplit,
	SUBSTRING(propertyAddress, CHARINDEX(',' , PropertyAddress) +1, LEN(propertyAddress)) AS citySplit
FROM housingWork

----adding split addrress
ALTER TABLE housingWork
ADD addressSplit nvarchar(250)

UPDATE housingWork
SET addressSplit = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', propertyAddress) -1 )

---adding split city 
ALTER TABLE housingWork
ADD citySplit nvarchar(250)

UPDATE housingWork
SET citySplit = SUBSTRING(PropertyAddress, CHARINDEX(',', propertyAddress) +1 , LEN(propertyAddress))


-------------------------------------------------------------------------------------------------------------------------
--3. Split owner address
	SELECT 
		PARSENAME(REPLACE(ownerAddress, ',' , '.'), 3) AS address,
		PARSENAME(REPLACE(ownerAddress,',', '.' ), 2) AS city,
		PARSENAME(REPLACE(ownerAddress, ',', '.'), 1) AS state
	FROM housingWork

--Split address
ALTER TABLE housingWork
ADD ownerAddressSplit nvarchar(250)

UPDATE housingWork
SET ownerAddressSplit = PARSENAME(REPLACE(ownerAddress, ',', '.'), 3)


--Split city
ALTER TABLE housingWork
ADD ownerCitySplit nvarChar(250)

UPDATE housingWork
SET ownerCitySplit = PARSENAME(REPLACE(ownerAddress, ',', '.'), 2)


--Split State
ALTER TABLE housingWork
ADD ownerAddressStateSplit nvarChar(250)

UPDATE housingWork
SET ownerAddressStateSplit = PARSENAME(REPLACE(ownerAddress, ',', '.'), 1)

-------------------------------------------------------------------------------------------------------------------------
--4. Fix Y --> Yes and N --> No
--checking count of yes no
SELECT 
	SoldAsVacant,
	COUNT(soldAsVacant) AS ynCount
FROM  housingWork
GROUP BY SoldAsVacant 
ORDER BY SoldAsVacant DESC

---convert y/n
SELECT 
	SoldAsVacant,
	CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END AS yesNo
FROM housingWork
GROUP BY SoldAsVacant

--Update the table with yes and no
UPDATE housingWork
SET SoldAsVacant = 
	CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END 



-------------------------------------------------------------------------------------------------------------------------
--5. Checking/ removing duplicates
WITH rowNum_CTE AS (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY parcelId, propertyAddress, salePrice, saleDate, legalReference ORDER BY uniqueId) AS row_num
FROM housingWork
)
SELECT * 
FROM rowNum_CTE
where row_num > 1
ORDER BY SalePrice DESC


-------------------------------------------------------------------------------------------------------------------------
--6) what landuse has highest salesPrice
SELECT TOP 10
	landuse,
	SUM(salePrice) as salePriceTotal
FROM housingWork
WHERE SoldAsVacant != 'Yes'
GROUP BY LandUse
ORDER BY salePriceTotal DESC

-------------------------------------------------------------------------------------------------------------------------
--7) What is the highest land usage over the years
WITH rankLandUse AS (
	SELECT 
		DATEPART(year, salesDateConvert) AS yr,
		LandUse,
		SUM(salePrice) as landPriceTotal,
		ROW_NUMBER () OVER (PARTITION BY DATEPART(year, salesDateConvert) ORDER BY SUM(salePrice) DESC) as row_num
	FROM housingWork
	WHERE SoldAsVacant != 'Yes'
	GROUP BY DATEPART(year, salesDateConvert), LandUse, SoldAsVacant
	)
SELECT 
	yr,
	LandUse,
	landPriceTotal
FROM rankLandUse
WHERE row_num = 1


-------------------------------------------------------------------------------------------------------------------------
-----------------------------------7a. Checking why RESIDENTIAL CONDO is the highest in 2015
SELECT * FROM housingWork
WHERE DATEPART(YEAR, salesDateConvert) = 2015
AND LandUse = 'RESIDENTIAL CONDO'
ORDER BY SalePrice desc


SELECT 
	addressSplit,
	LandUse,
	SUM(SalePrice) as total,
	MIN(salePrice) as min,
	MAX(salePrice) as max,
	COUNT(landUse) as totalbought
FROM housingWork
WHERE DATEPART(YEAR, salesDateConvert) = 2015
	AND LandUse IN ('SINGLE FAMILY', 'RESIDENTIAL CONDO')
GROUP BY LandUse, addressSplit


-------------------------------------------------------------------------------------------------------------------------
--8. Remove Duplicates that have base on LandUse, salesDateConvert, SalePrice, LegalReference/ columns needed
--Put into temptable

CREATE TABLE #TempHousingWork (
    UniqueID INT,
    parcelId VARCHAR(50),
    LandUse VARCHAR(100),
    addressSplit VARCHAR(255),
    citySplit VARCHAR(100),
    salesDateConvert DATE,
    SalePrice INT, 
    LegalReference VARCHAR(255),
    SoldAsVacant VARCHAR(10),
    ownerAddressSplit VARCHAR(255),
    ownerCitySplit VARCHAR(100),
    ownerAddressStateSplit VARCHAR(50)
)

INSERT INTO #TempHousingWork
SELECT 
    UniqueID,
    parcelId,
    LandUse,
    addressSplit,
    citySplit,
    salesDateConvert,
    SalePrice,  
    LegalReference,
    SoldAsVacant,
    ownerAddressSplit,
    ownerCitySplit,
    ownerAddressStateSplit
FROM housingWork;

ALTER TABLE #TempHousingWork
ALTER COLUMN SalePrice BIGINT

select * from #TempHousingWork


--8a. Removing duplicates (base on LandUse, salesDateConvert, SalePrice, LegalReference)
WITH singleValue AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY LandUse, salesDateConvert, SalePrice, LegalReference ORDER BY UniqueID) AS row_numRank
    FROM #TempHousingWork
)
DELETE t
FROM #TempHousingWork t
JOIN singleValue sv ON t.UniqueID = sv.UniqueID
WHERE sv.row_numRank > 1; ;

SELECT * from #TempHousingWork



-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

--9. rechecking what landuse has highest salesPrice
SELECT TOP 10
	landuse,
	SUM(CAST(salePrice AS bigint)) as salePriceTotal
FROM #TempHousingWork
WHERE SoldAsVacant != 'Yes'
GROUP BY LandUse
ORDER BY salePriceTotal DESC


--10. Highest land use per yr
WITH rankLandUse AS (
	SELECT 
		DATEPART(year, salesDateConvert) AS yr,
		LandUse,
		SUM(CAST(salePrice AS bigint)) as landPriceTotal,
		AVG(CAST(salePrice AS bigint)) as avgPriceTotal,
		ROW_NUMBER () OVER (PARTITION BY DATEPART(year, salesDateConvert) ORDER BY SUM(CAST(salePrice AS bigint)) DESC) as row_num
	FROM #TempHousingWork
	WHERE SoldAsVacant != 'Yes'
	GROUP BY DATEPART(year, salesDateConvert), LandUse, SoldAsVacant
	)
SELECT 
	yr,
	LandUse,
	landPriceTotal,
	avgPriceTotal
FROM rankLandUse
WHERE row_num = 1

--11. what state has the highest salePrice
SELECT 
	citySplit,
	SUM(SalePrice) AS cityTotal
FROM #TempHousingWork




WHERE LandUse = 'SINGLE FAMILY'
	AND citySplit IS NOT NULL
GROUP BY citySplit
ORDER BY cityTotal desc
