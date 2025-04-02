use housingProject
SELECT * FROM housing


SELECT * INTO housingWork 
FROM housing

select * from housingWork
-------------------------------------------------------------------------------------------------------------------------
---Standarcize date 
SELECT 
	CONVERT(date, SaleDate) as SalesDate
FROM housingWork

ALTER TABLE housingWork
ADD salesDateConvert DATE

UPDATE housingWork
SET salesDateConvert = CONVERT(date, SaleDate)

-------------------------------------------------------------------------------------------------------------------------
---Replace NULL addresses with Parcel ID and not with same uniqueID

SELECT 
	a.ParcelID,
	a.PropertyAddress,
	b.ParcelID,
	b.PropertyAddress,
	ISNULL(a.propertyAddress, B.PropertyAddress) AS address
FROM housingWork a 
JOIN housingWork b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] != b.[UniqueID ]
WHERE a.PropertyAddress IS NULL 

UPDATE a
SET PropertyAddress = ISNULL(a.propertyAddress, B.PropertyAddress)
FROM housingWork a 
JOIN housingWork b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] != b.[UniqueID ]
WHERE a.PropertyAddress IS NULL 

-- check
SELECT * 
FROM housingWork
WHERE PropertyAddress is null

-------------------------------------------------------------------------------------------------------------------------
---updating property address
SELECT PropertyAddress,
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', propertyAddress) -1 ) AS addressSplit,
	SUBSTRING(PropertyAddress, CHARINDEX(',', propertyAddress) +1 ,LEN(propertyAddress)) as citySplit
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

SELECT * 
FROM housingWork

-------------------------------------------------------------------------------------------------------------------------
---owner address

select 
	PARSENAME(REPLACE(ownerAddress, ',', '.'), 3) AS ownerAddressSplit,
	PARSENAME(REPLACE(ownerAddress, ',', '.'), 2) AS ownerCitySplit,
	PARSENAME(REPLACE(ownerAddress, ',', '.'), 1) AS ownerAddressStateSplit
from housingWork


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
---Vaccants

SELECT DISTINCT
	SoldAsVacant,
	COUNT(soldAsVacant) as c
FROM housingWork
GROUP BY SoldAsVacant
ORDER BY c DESC


SELECT SoldAsVacant,
	CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END 
FROM housingWork

UPDATE housingWork
SET SoldAsVacant = 
	CASE 
		WHEN SoldAsVacant = 'Y' THEN 'Yes'
		WHEN SoldAsVacant = 'N' THEN 'No'
		ELSE SoldAsVacant
	END 

-------------------------------------------------------------------------------------------------------------------------
---Checking/ removing duplicates
WITH rowNum_CTE AS (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY parcelId, propertyAddress, salePrice, saleDate, legalReference ORDER BY uniqueId) AS row_num
FROM housingWork
)
SELECT * 
FROM rowNum_CTE
where row_num > 1
ORDER BY SalePrice DESC

--DELETE
--FROM rowNum_CTE
--where row_num > 1



--removing unused column
ALTER TABLE housingWork
DROP COLUMN 
	saleDate,
	ownerAddress,
	taxdistrict, 
	PropertyAddress


SELECT DISTINCT citySplit
FROM housingWork

USE housingProject






-------------------------------------------------------------------------------------------------------------------------
--1) what land use has highest salesPrice
SELECT TOP 10
	landuse,
	SUM(salePrice) as salePriceTotal
FROM housingWork
WHERE SoldAsVacant != 'Yes'
GROUP BY LandUse
ORDER BY salePriceTotal DESC

SELECT distinct datepart(year,salesDateConvert)
FROM housingWork


--2) Highest land use per yr
WITH rankLandUse AS (
	SELECT 
		DATEPART(year, salesDateConvert) AS yr,
		LandUse,
		SUM(salePrice) as landPriceTotal,
		ROW_NUMBER () OVER (PARTITION BY DATEPART(year, salesDateConvert) ORDER BY SUM(salePrice) DESC) as row_num
	FROM NASHhousingWork
	WHERE SoldAsVacant != 'Yes'
	GROUP BY DATEPART(year, salesDateConvert), LandUse, SoldAsVacant
	)
SELECT 
	yr,
	LandUse,
	landPriceTotal
FROM rankLandUse
WHERE row_num = 1

-----------------------------------drill down to why 2015 different
SELECT * FROM housingWork
WHERE DATEPART(YEAR, salesDateConvert) = 2015
AND LandUse = 'RESIDENTIAL CONDO'
ORDER BY SalePrice desc

--min/max total
SELECT 
	LandUse,
	SUM(SalePrice) as total,
	MIN(salePrice) as min,
	MAX(salePrice) as max,
	COUNT(landUse) as totalbought
FROM NASHhousingWork
WHERE DATEPART(YEAR, salesDateConvert) = 2015
	AND LandUse IN ('SINGLE FAMILY', 'RESIDENTIAL CONDO')
GROUP BY LandUse



select * from NASHhousingWork














--------------------------------------------------------------------------------------------------------------------
WITH DuplicateCheck AS (
    SELECT 
        LandUse, 
        SalePrice, 
        LegalReference, 
        ROW_NUMBER() OVER (PARTITION BY LandUse, SalePrice, LegalReference ORDER BY (SELECT NULL)) AS row_rank
    FROM housingWork
)
SELECT *
FROM DuplicateCheck
WHERE row_rank > 1;

SELECT *
FROM housing
WHERE LegalReference = '20160505-0044702'


WITH Deduplicated AS (
    SELECT 
        LandUse, 
        SalePrice, 
        LegalReference, 
        ROW_NUMBER() OVER (PARTITION BY LandUse, SalePrice, LegalReference ORDER BY LegalReference) AS row_num
    FROM housingWork
)
SELECT LandUse, SalePrice, LegalReference
FROM Deduplicated
WHERE row_num = 1;
--- avg sales price for single family 

-- what city has highest 




























-----------------------UNUSED CODE 

--SELECT * FROM housingWork

--SELECT * FROM housingWork
--WHERE DATEPART(YEAR, salesDateConvert) = 2015
--AND LandUse = 'RESIDENTIAL CONDO'
--ORDER BY SalePrice desc



--CREATE TABLE #housingCombine (
--	landUse varchar(100),
--	SaleDateConcert DATE,
--	addressSplit,
--	citySplit

--WITH singleValue AS (
--	SELECT *,
--	ROW_NUMBER () OVER (PARTITION BY LandUse, salesDateConvert, SalePrice, LegalReference ORDER BY UniqueID) AS row_numRank
--	FROM housingWork
--)

--SELECT * 
--FROM singleValue
--WHERE row_numRank > 1
--ORDER BY row_numRank DESC

--SELECT 
--	[UniqueID ],
--	parcelId,
--	LandUse,
--	addressSplit,
--	citySplit,
--	salesDateConvert,
--	SalePrice,
--	LegalReference,
--	SoldAsVacant,
--	ownerAddressSplit,
--	ownerCitySplit,
--	ownerAddressStateSplit,
--FROM housingWork




use housingProject
select * from housing

SELECT * FROM NASHhousingWork
WHERE DATEPART(YEAR, salesDateConvert) = 2015
AND LandUse = 'RESIDENTIAL CONDO'
ORDER BY SalePrice desc

--------------------------------------------------------------------------------------------------------------------
--SELECT * 
--FROM singleValue
--WHERE row_numRank = 1
--ORDER BY row_numRank DESC

--UPDATE #TempHousingWork
--SET = 
--WITH singleValue AS (
--	SELECT *,
--	ROW_NUMBER () OVER (PARTITION BY LandUse, salesDateConvert, SalePrice, LegalReference ORDER BY UniqueID) AS row_numRank
--	FROM #TempHousingWork
--)

--SELECT * 
--FROM singleValue
--WHERE row_numRank = 1
--ORDER BY row_numRank DESC