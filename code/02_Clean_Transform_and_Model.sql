USE R3;
GO

-- Tạo bảng clean_data từ original_data
SELECT * INTO clean_data FROM original_data;
GO

/*-------------------------------------
1. Làm sạch giá trị price
-------------------------------------*/
CREATE PROCEDURE Price AS
BEGIN
    UPDATE clean_data
    SET price = CAST(REPLACE(price, N'đồng/tháng', '') AS FLOAT) / 1000
    WHERE price LIKE N'%đồng/tháng%';

    UPDATE clean_data
    SET price = CAST(REPLACE(price, N'triệu/tháng', '') AS FLOAT)
    WHERE price LIKE N'%triệu/tháng%';

    DELETE FROM clean_data 
    WHERE TRY_CAST(price AS FLOAT) IS NULL;
END;
GO

EXEC Price;
GO

/*-------------------------------------
2. Chuyển đổi ngày xuất bản và hết hạn
-------------------------------------*/
CREATE FUNCTION ExtractDate(@DateString NVARCHAR(50))
RETURNS DATE AS
BEGIN
    RETURN TRY_CONVERT(DATE, RIGHT(@DateString, 10), 103);
END;
GO

UPDATE clean_data
SET published_date = dbo.ExtractDate(published_date),
    expiration_date = dbo.ExtractDate(expiration_date);
GO

/*-------------------------------------
3. Xóa đơn vị diện tích
-------------------------------------*/
CREATE PROCEDURE Area AS
BEGIN
    UPDATE clean_data
    SET area = CAST(REPLACE(area, 'm2', '') AS FLOAT);
END;
GO

EXEC Area;
GO

/*-------------------------------------
4. Tách district từ address
-------------------------------------*/
CREATE FUNCTION onlyDistrict(@address NVARCHAR(255))
RETURNS NVARCHAR(255) AS
BEGIN
    -- Xử lý chuỗi
    SET @address = CASE 
        WHEN @address LIKE N'%, Hồ Chí Minh%' THEN REPLACE(@address, N', Hồ Chí Minh', '')
        WHEN @address LIKE N'%, TP.HCM%' THEN REPLACE(@address, N', TP.HCM', '')
        ELSE @address
    END;
    
    DECLARE @district NVARCHAR(255) = RIGHT(@address, CHARINDEX(',', REVERSE(@address)+',')-1);
    
    RETURN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(@district, N'Quận', ''), N'Huyện', ''), N'Thành phố', '')));
END;
GO

ALTER TABLE clean_data ADD district NVARCHAR(255);
UPDATE clean_data SET district = dbo.onlyDistrict(address);
GO

/*-------------------------------------
5. Xử lý dữ liệu không có thông tin
-------------------------------------*/
CREATE FUNCTION Info(@input NVARCHAR(MAX))
RETURNS NVARCHAR(MAX) AS
BEGIN
    RETURN CASE WHEN @input = N'không có thông tin' THEN N'không có' ELSE @input END;
END;
GO

UPDATE clean_data
SET basic_amenities = dbo.Info(basic_amenities),
    security = dbo.Info(security),
    public_amenities = dbo.Info(public_amenities);
GO

-- Thêm internet vào public_amenities nếu has_internet = 'có'
UPDATE clean_data
SET public_amenities = CASE
    WHEN public_amenities = N'không có' THEN IIF(has_internet = 'có', 'internet', public_amenities)
    ELSE CONCAT(public_amenities, IIF(has_internet = 'có', ', internet', ''))
END;
GO

/*-------------------------------------
6. Chuyển convenient_location thành chuẩn
-------------------------------------*/
UPDATE clean_data
SET convenient_location = IIF(convenient_location = N'có', N'gần đại học', N'không có');
GO

/*-------------------------------------
7. Xóa các cột không cần thiết
-------------------------------------*/
CREATE PROCEDURE RemoveUnnecessaryColumns
    @table_name NVARCHAR(128),
    @columns_to_remove NVARCHAR(MAX)
AS
BEGIN
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @table_name)
    BEGIN
        EXEC sp_executesql N'ALTER TABLE ' + QUOTENAME(@table_name) + ' DROP COLUMN ' + @columns_to_remove;
    END
END;
GO

EXEC RemoveUnnecessaryColumns 'clean_data', 'title, listing_type, tenant_type, has_internet, address';
GO

/*-------------------------------------
8. Tạo mô hình dữ liệu chuẩn hóa
-------------------------------------*/
CREATE TABLE District (district_id INT PRIMARY KEY IDENTITY, district_name NVARCHAR(20) UNIQUE);
CREATE TABLE Amenities_Type (type_id INT PRIMARY KEY IDENTITY, amenity_type NVARCHAR(20));
CREATE TABLE Room (
    room_id VARCHAR(6) PRIMARY KEY,
    area FLOAT,
    price FLOAT,
    published_date DATE,
    expiration_date DATE,
    district_id INT FOREIGN KEY REFERENCES District(district_id)
);
CREATE TABLE Amenities_Details (
    amenities_id INT PRIMARY KEY IDENTITY,
    amenity_name NVARCHAR(20),
    type_id INT FOREIGN KEY REFERENCES Amenities_Type(type_id)
);
CREATE TABLE Room_Amenities (
    room_id VARCHAR(6),
    amenities_id INT,
    PRIMARY KEY(room_id, amenities_id),
    FOREIGN KEY(room_id) REFERENCES Room(room_id),
    FOREIGN KEY(amenities_id) REFERENCES Amenities_Details(amenities_id)
);
GO
