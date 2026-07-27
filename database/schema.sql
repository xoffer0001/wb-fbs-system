--
-- PostgreSQL database dump
--

\restrict 9yns6caYrXgcfPR2DXdkKemABhg4ie26UZgdtIKz1JySWooXtnA2Dem1Q9J1DY5

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgagent; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgagent;


--
-- Name: SCHEMA pgagent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA pgagent IS 'pgAgent system tables';


--
-- Name: sima_land; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sima_land;


--
-- Name: pgagent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgagent WITH SCHEMA pgagent;


--
-- Name: EXTENSION pgagent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgagent IS 'A PostgreSQL job scheduler';


--
-- Name: calculate_logistics_cost(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.calculate_logistics_cost(p_dimensions jsonb) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Используем ФИНАЛЬНОЕ название склада для тарифов Marketplace (FBS)
    v_warehouse_name CONSTANT TEXT := 'Белая дача'; 
    
    v_base_rate_text TEXT;      
    v_liter_rate_text TEXT;     
    v_base_rate NUMERIC;        
    v_liter_rate NUMERIC;       
    
    v_volume_liters NUMERIC;    
    v_length NUMERIC;
    v_width NUMERIC;
    v_height NUMERIC;
BEGIN
    -- 1. Извлечение текстовых тарифов Marketplace (FBS)
    SELECT 
        box_delivery_marketplace_base, 
        box_delivery_marketplace_liter
    INTO 
        v_base_rate_text, 
        v_liter_rate_text
    FROM 
        public.wb_tarif_box
    WHERE 
        warehouse_name = v_warehouse_name; -- <--- Использование 'Белая дача'

    -- Проверка, найден ли тариф для склада
    IF v_base_rate_text IS NULL THEN
        RAISE WARNING 'Тариф Marketplace для склада % не найден. Возврат 999.00.', v_warehouse_name;
        RETURN 999.00;
    END IF;

    -- 2. Преобразование текстовых тарифов в NUMERIC
    v_base_rate := COALESCE(v_base_rate_text, '0')::NUMERIC;
    v_liter_rate := COALESCE(v_liter_rate_text, '0')::NUMERIC;

    -- 3. Извлечение размеров и расчет объема в литрах
    v_length := (p_dimensions ->> 'length')::NUMERIC;
    v_width := (p_dimensions ->> 'width')::NUMERIC;
    v_height := (p_dimensions ->> 'height')::NUMERIC;

    IF v_length IS NULL OR v_width IS NULL OR v_height IS NULL OR v_length = 0 OR v_width = 0 OR v_height = 0 THEN
        RAISE WARNING 'Отсутствуют или нулевые размеры для расчета объема!';
        RETURN 999.00; 
    END IF;

    v_volume_liters := (v_length * v_width * v_height) / 1000.0;
    
    -- 4. Расчет итоговой стоимости логистики (FBS)
    -- Логика: База (1-й литр) + (Объем - 1) * Ставка за доп. литр
    IF v_volume_liters > 1.0 THEN
        RETURN v_base_rate + (v_volume_liters - 1.0) * v_liter_rate;
    ELSE
        -- Если объем <= 1 литра, используем только базовую ставку.
        RETURN v_base_rate; 
    END IF;

END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: wb_commission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wb_commission (
    id integer NOT NULL,
    kgvp_booking numeric(6,2),
    kgvp_marketplace numeric(6,2),
    kgvp_pickup numeric(6,2),
    kgvp_supplier numeric(6,2),
    kgvp_supplier_express numeric(6,2),
    paid_storage_kgvp numeric(6,2),
    parent_id integer,
    parent_name character varying(255),
    subject_id integer,
    subject_name character varying(255)
);


--
-- Name: COLUMN wb_commission.kgvp_marketplace; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.kgvp_marketplace IS 'Комиссия по модели Маркетплейс (FBS), %';


--
-- Name: COLUMN wb_commission.kgvp_pickup; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.kgvp_pickup IS 'Комиссия по модели Самовывоз из магазина продавца (C&C), %';


--
-- Name: COLUMN wb_commission.kgvp_supplier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.kgvp_supplier IS 'Комиссия по моделям Витрина (DBS) и Курьер WB (DBW), %';


--
-- Name: COLUMN wb_commission.kgvp_supplier_express; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.kgvp_supplier_express IS 'Комиссия по модели Витрина экспресс (EDBS), %';


--
-- Name: COLUMN wb_commission.paid_storage_kgvp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.paid_storage_kgvp IS 'Комиссия по модели «Склад WB» (FBW), %';


--
-- Name: COLUMN wb_commission.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.parent_id IS 'ID родительской категории';


--
-- Name: COLUMN wb_commission.parent_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.parent_name IS 'Название родительской категории';


--
-- Name: COLUMN wb_commission.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.subject_id IS 'ID предмета';


--
-- Name: COLUMN wb_commission.subject_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_commission.subject_name IS 'Название предмета';


--
-- Name: wb_price_unit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wb_price_unit (
    nmid bigint NOT NULL,
    vendor_code text,
    csv_str_wholeprice numeric,
    subject_id integer,
    dimensions jsonb,
    buyout_rate_pct numeric,
    acquiring_pct numeric,
    internal_fee_pct numeric,
    tax_pct numeric,
    desired_margin_pct numeric,
    current_wb_price numeric(10,2) DEFAULT NULL::numeric,
    fixed_fee_pack numeric,
    warning_pct_drop numeric,
    warning_pct_grow numeric,
    discounted_wb_price numeric(10,2),
    club_wb_price numeric(10,2),
    discount numeric(5,2)
);


--
-- Name: TABLE wb_price_unit; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wb_price_unit IS 'Центральная таблица для консолидации данных и параметров для расчета цены продажи Wildberries.';


--
-- Name: COLUMN wb_price_unit.nmid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.nmid IS 'Артикул Wildberries (WB). PRIMARY KEY. Используется для обновления цены по API.';


--
-- Name: COLUMN wb_price_unit.vendor_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.vendor_code IS 'Артикул продавца. Используется для JOIN с таблицей закупочной цены.';


--
-- Name: COLUMN wb_price_unit.csv_str_wholeprice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.csv_str_wholeprice IS 'Закупочная цена / Себестоимость (C_zak). Базовая цена для расчета.';


--
-- Name: COLUMN wb_price_unit.subject_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.subject_id IS 'ID категории товара. Необходим для получения актуальной комиссии WB (K_wb).';


--
-- Name: COLUMN wb_price_unit.dimensions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.dimensions IS 'Размеры упаковки (JSONB). Необходимы для расчета стоимости логистики (C_log).';


--
-- Name: COLUMN wb_price_unit.buyout_rate_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.buyout_rate_pct IS 'Процент выкупа (%). Используется для корректировки C_log с учетом возвратов.';


--
-- Name: COLUMN wb_price_unit.acquiring_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.acquiring_pct IS 'Эквайринг WB (в %). Вычитается из цены продажи.';


--
-- Name: COLUMN wb_price_unit.internal_fee_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.internal_fee_pct IS 'Внутренний сбор / Конструктор тарифов (в %). Вычитается из цены продажи.';


--
-- Name: COLUMN wb_price_unit.tax_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.tax_pct IS 'Налоговая ставка (в %). Вычитается из цены продажи.';


--
-- Name: COLUMN wb_price_unit.desired_margin_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.desired_margin_pct IS 'Желаемая маржинальность (в %). Используется для расчета желаемой прибыли.';


--
-- Name: COLUMN wb_price_unit.current_wb_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.current_wb_price IS 'Текущая цена товара на Wildberries, полученная через API (поле discountedPrice). Используется для сравнения с расчетной ценой.';


--
-- Name: COLUMN wb_price_unit.fixed_fee_pack; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.fixed_fee_pack IS 'Фулфилмент фиксированный - 60 руб. за упаковку.';


--
-- Name: COLUMN wb_price_unit.warning_pct_drop; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.warning_pct_drop IS 'Максимальный процент падения продажной цены';


--
-- Name: COLUMN wb_price_unit.warning_pct_grow; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_price_unit.warning_pct_grow IS 'Максимальный процент увеличения продажной цены';


--
-- Name: calculated_prices; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.calculated_prices AS
 WITH logistics_and_fees AS (
         SELECT p.nmid,
            p.vendor_code,
            p.csv_str_wholeprice AS c_zak,
            c.kgvp_marketplace AS k_wb_pct,
            p.internal_fee_pct,
            p.current_wb_price,
            p.discounted_wb_price,
            p.club_wb_price,
            p.discount,
            (p.desired_margin_pct / 100.0) AS desired_margin_pct_c,
            (p.buyout_rate_pct / 100.0) AS buyout_rate_pct_c,
            (p.acquiring_pct / 100.0) AS acquiring_pct_c,
            (p.tax_pct / 100.0) AS tax_pct_c,
            p.fixed_fee_pack AS c_pack,
            p.warning_pct_drop AS pct_drop,
            p.warning_pct_grow AS pct_grow,
            ((p.csv_str_wholeprice IS NOT NULL) AND (p.desired_margin_pct IS NOT NULL) AND (p.buyout_rate_pct IS NOT NULL) AND (p.acquiring_pct IS NOT NULL) AND (p.internal_fee_pct IS NOT NULL) AND (p.tax_pct IS NOT NULL) AND (p.fixed_fee_pack IS NOT NULL) AND (p.warning_pct_drop IS NOT NULL) AND (p.warning_pct_grow IS NOT NULL)) AS is_config_complete,
            public.calculate_logistics_cost(p.dimensions) AS c_log_raw,
            COALESCE((public.calculate_logistics_cost(p.dimensions) / NULLIF((p.buyout_rate_pct / 100.0), (0)::numeric)), 999999.0) AS c_log_adjusted,
            (((((1.0 - (c.kgvp_marketplace / 100.0)) - (p.acquiring_pct / 100.0)) - (p.internal_fee_pct / 100.0)) - (p.tax_pct / 100.0)) - (p.desired_margin_pct / 100.0)) AS denominator_with_margin,
            NULLIF(((((1.0 - (c.kgvp_marketplace / 100.0)) - (p.acquiring_pct / 100.0)) - (p.internal_fee_pct / 100.0)) - (p.tax_pct / 100.0)), (0)::numeric) AS denominator_for_bep,
            COALESCE(((p.csv_str_wholeprice + (public.calculate_logistics_cost(p.dimensions) / NULLIF((p.buyout_rate_pct / 100.0), (0)::numeric))) + p.fixed_fee_pack), 999999.0) AS numerator_base_cost
           FROM (public.wb_price_unit p
             JOIN public.wb_commission c ON ((p.subject_id = c.subject_id)))
        ), calculated_final_price AS (
         SELECT t.nmid,
            t.vendor_code,
            t.c_zak,
            t.k_wb_pct,
            t.internal_fee_pct,
            t.current_wb_price,
            t.discounted_wb_price,
            t.club_wb_price,
            t.discount,
            t.desired_margin_pct_c,
            t.buyout_rate_pct_c,
            t.acquiring_pct_c,
            t.tax_pct_c,
            t.c_pack,
            t.pct_drop,
            t.pct_grow,
            t.is_config_complete,
            t.c_log_raw,
            t.c_log_adjusted,
            t.denominator_with_margin,
            t.denominator_for_bep,
            t.numerator_base_cost,
                CASE
                    WHEN (NOT t.is_config_complete) THEN NULL::numeric
                    WHEN (ceiling(COALESCE((t.numerator_base_cost / NULLIF(t.denominator_with_margin, (0)::numeric)), 999999.0)) < (ceiling(COALESCE((((t.c_zak + t.c_log_adjusted) + t.c_pack) / t.denominator_for_bep), 999999.0)) + (1)::numeric)) THEN (ceiling(COALESCE((((t.c_zak + t.c_log_adjusted) + t.c_pack) / t.denominator_for_bep), 999999.0)) + (1)::numeric)
                    ELSE ceiling(COALESCE((t.numerator_base_cost / NULLIF(t.denominator_with_margin, (0)::numeric)), 999999.0))
                END AS final_price_safe,
                CASE
                    WHEN (NOT t.is_config_complete) THEN NULL::numeric
                    ELSE ceiling(COALESCE((((t.c_zak + t.c_log_adjusted) + t.c_pack) / t.denominator_for_bep), 999999.0))
                END AS break_even_price
           FROM logistics_and_fees t
        ), final_calc AS (
         SELECT calculated_final_price.nmid,
            calculated_final_price.vendor_code,
            calculated_final_price.c_zak,
            calculated_final_price.k_wb_pct,
            calculated_final_price.internal_fee_pct,
            calculated_final_price.current_wb_price,
            calculated_final_price.discounted_wb_price,
            calculated_final_price.club_wb_price,
            calculated_final_price.discount,
            calculated_final_price.desired_margin_pct_c,
            calculated_final_price.buyout_rate_pct_c,
            calculated_final_price.acquiring_pct_c,
            calculated_final_price.tax_pct_c,
            calculated_final_price.c_pack,
            calculated_final_price.pct_drop,
            calculated_final_price.pct_grow,
            calculated_final_price.is_config_complete,
            calculated_final_price.c_log_raw,
            calculated_final_price.c_log_adjusted,
            calculated_final_price.denominator_with_margin,
            calculated_final_price.denominator_for_bep,
            calculated_final_price.numerator_base_cost,
            calculated_final_price.final_price_safe,
            calculated_final_price.break_even_price,
                CASE
                    WHEN (NOT calculated_final_price.is_config_complete) THEN calculated_final_price.discounted_wb_price
                    WHEN (calculated_final_price.discounted_wb_price IS NULL) THEN NULL::numeric
                    WHEN (calculated_final_price.final_price_safe < (calculated_final_price.discounted_wb_price * ((1)::numeric - (calculated_final_price.pct_drop / 100.0)))) THEN calculated_final_price.discounted_wb_price
                    WHEN (calculated_final_price.final_price_safe > (calculated_final_price.discounted_wb_price * ((1)::numeric + (calculated_final_price.pct_grow / 100.0)))) THEN calculated_final_price.discounted_wb_price
                    ELSE calculated_final_price.final_price_safe
                END AS calc_price_to_send
           FROM calculated_final_price
        )
 SELECT nmid,
    vendor_code,
    c_zak,
    c_pack,
    c_log_raw,
    c_log_adjusted,
    k_wb_pct,
    desired_margin_pct_c AS desired_margin_pct,
        CASE
            WHEN is_config_complete THEN ceiling((((c_zak + c_log_adjusted) + c_pack) + (1)::numeric))
            ELSE NULL::numeric
        END AS min_safe_price_base,
        CASE
            WHEN is_config_complete THEN numerator_base_cost
            ELSE NULL::numeric
        END AS numerator_with_margin,
    break_even_price,
    final_price_safe,
    current_wb_price,
        CASE
            WHEN (NOT is_config_complete) THEN NULL::numeric
            WHEN ((discounted_wb_price IS NULL) OR (discounted_wb_price = (0)::numeric)) THEN NULL::numeric
            ELSE round((((final_price_safe - discounted_wb_price) / discounted_wb_price) * (100)::numeric), 2)
        END AS price_delta_pct,
        CASE
            WHEN (NOT is_config_complete) THEN 'MISSING_CONFIG'::text
            WHEN (discounted_wb_price IS NULL) THEN 'NO_DATA'::text
            WHEN (final_price_safe < (discounted_wb_price * ((1)::numeric - (pct_drop / 100.0)))) THEN 'WARNING_LOW'::text
            WHEN (final_price_safe > (discounted_wb_price * ((1)::numeric + (pct_grow / 100.0)))) THEN 'WARNING_HIGH'::text
            ELSE 'OK'::text
        END AS price_status,
    calc_price_to_send AS price_to_send,
        CASE
            WHEN (NOT is_config_complete) THEN NULL::numeric
            WHEN (calc_price_to_send IS NULL) THEN NULL::numeric
            ELSE round((calc_price_to_send - (((c_zak + c_log_adjusted) + c_pack) + (calc_price_to_send * ((((k_wb_pct / 100.0) + acquiring_pct_c) + (internal_fee_pct / 100.0)) + tax_pct_c)))), 2)
        END AS margin_rub,
    discounted_wb_price,
    club_wb_price,
    discount
   FROM final_calc;


--
-- Name: product_prices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_prices (
    id integer NOT NULL,
    vendor_code text NOT NULL,
    price numeric(10,2) NOT NULL,
    "timestamp" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    stock integer,
    stock_timestamp timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: TABLE product_prices; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_prices IS 'История цен и остатков у поставщика. Сбор раз в день.';


--
-- Name: COLUMN product_prices.vendor_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_prices.vendor_code IS 'aid от поставщика';


--
-- Name: COLUMN product_prices.price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_prices.price IS 'закупочная цена';


--
-- Name: COLUMN product_prices."timestamp"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_prices."timestamp" IS 'время обновления цены';


--
-- Name: COLUMN product_prices.stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_prices.stock IS 'остаток у поставщика';


--
-- Name: COLUMN product_prices.stock_timestamp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_prices.stock_timestamp IS 'Время, когда остаток (stock) был последний раз обновлен от поставщика.';


--
-- Name: product_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_prices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: product_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_prices_id_seq OWNED BY public.product_prices.id;


--
-- Name: proxy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proxy (
    login character varying NOT NULL,
    country character varying,
    site character varying NOT NULL
);


--
-- Name: supplier_stock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_stock (
    vendor_code text NOT NULL,
    stock integer,
    price numeric(10,2),
    stock_timestamp timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    shipping_date timestamp with time zone,
    supplier_id bigint NOT NULL
);


--
-- Name: TABLE supplier_stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.supplier_stock IS 'Актуальные остатки и цены, полученные от поставщика. Используется Zennoposter для отправки в WB по API. Содержит только одну уникальную запись на каждый товар.';


--
-- Name: COLUMN supplier_stock.vendor_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.supplier_stock.vendor_code IS 'Артикул продавца (SKU/Баркод), который используется для идентификации товара в Wildberries. Является первичным ключом.';


--
-- Name: COLUMN supplier_stock.stock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.supplier_stock.stock IS 'Актуальный остаток товара, который должен быть передан в Wildberries.';


--
-- Name: COLUMN supplier_stock.price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.supplier_stock.price IS 'Актуальная цена товара.';


--
-- Name: COLUMN supplier_stock.stock_timestamp; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.supplier_stock.stock_timestamp IS 'Время, когда данные (остаток и цена) были последний раз обновлены от поставщика.';


--
-- Name: COLUMN supplier_stock.shipping_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.supplier_stock.shipping_date IS 'Дата и время, к которым товар должен быть отгружен поставщиком. Критично для WB API.';


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    supplier_id bigint NOT NULL,
    supplier_code text NOT NULL,
    supplier_name text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    comment text
);


--
-- Name: TABLE suppliers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.suppliers IS 'Таблица поставщиков';


--
-- Name: COLUMN suppliers.supplier_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.suppliers.supplier_id IS 'Уникальный внутренний идентификатор поставщика';


--
-- Name: COLUMN suppliers.supplier_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.suppliers.supplier_code IS 'Короткий код поставщика (используется в логике и импортах)';


--
-- Name: COLUMN suppliers.supplier_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.suppliers.supplier_name IS 'Название поставщика';


--
-- Name: COLUMN suppliers.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.suppliers.is_active IS 'Флаг активности поставщика (true — используется, false — отключен)';


--
-- Name: COLUMN suppliers.comment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.suppliers.comment IS 'Комментарий или служебная информация по поставщику';


--
-- Name: suppliers_supplier_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.suppliers_supplier_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: suppliers_supplier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.suppliers_supplier_id_seq OWNED BY public.suppliers.supplier_id;


--
-- Name: wb_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wb_cards (
    nmid bigint NOT NULL,
    imtid bigint,
    nmuuid text,
    subjectid integer,
    subjectname text,
    vendorcode text,
    brand text,
    title text,
    description text,
    needkiz boolean,
    photos jsonb,
    dimensions jsonb,
    characteristics jsonb,
    sizes jsonb,
    tags jsonb,
    createdat timestamp without time zone,
    updatedat timestamp without time zone
);


--
-- Name: TABLE wb_cards; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wb_cards IS 'Таблица с товарами выгруженными из Товары и цены WB, без лишних полей.';


--
-- Name: wb_commission_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wb_commission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wb_commission_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wb_commission_id_seq OWNED BY public.wb_commission.id;


--
-- Name: wb_tarif_box; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wb_tarif_box (
    id integer NOT NULL,
    dt_update timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    dt_till_max date,
    warehouse_name text,
    geo_name text,
    box_delivery_base text,
    box_delivery_coef_expr text,
    box_delivery_liter text,
    box_delivery_marketplace_base text,
    box_delivery_marketplace_coef_expr text,
    box_delivery_marketplace_liter text,
    box_storage_base text,
    box_storage_coef_expr text,
    box_storage_liter text
);


--
-- Name: TABLE wb_tarif_box; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.wb_tarif_box IS 'Тарифы Wildberries по коробочной логистике (FBS/Marketplace) для складов WB.';


--
-- Name: COLUMN wb_tarif_box.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.id IS 'Первичный ключ записи тарифа.';


--
-- Name: COLUMN wb_tarif_box.dt_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.dt_update IS 'Дата и время последнего обновления тарифа.';


--
-- Name: COLUMN wb_tarif_box.dt_till_max; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.dt_till_max IS 'Дата окончания действия тарифа, если указана Wildberries.';


--
-- Name: COLUMN wb_tarif_box.warehouse_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.warehouse_name IS 'Название склада WB. Используется для выбора тарифов логистики. Например: Белая дача, Екатеринбург.';


--
-- Name: COLUMN wb_tarif_box.geo_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.geo_name IS 'Географический регион или кластер склада WB.';


--
-- Name: COLUMN wb_tarif_box.box_delivery_base; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_base IS 'Базовая стоимость доставки короба для модели FBW/FBO.';


--
-- Name: COLUMN wb_tarif_box.box_delivery_coef_expr; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_coef_expr IS 'Формула или коэффициент расчета доставки короба для модели FBW/FBO.';


--
-- Name: COLUMN wb_tarif_box.box_delivery_liter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_liter IS 'Стоимость доставки каждого дополнительного литра объема для модели FBW/FBO.';


--
-- Name: COLUMN wb_tarif_box.box_delivery_marketplace_base; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_marketplace_base IS 'Базовая стоимость доставки короба для модели Marketplace (FBS). Используется в calculate_logistics_cost().';


--
-- Name: COLUMN wb_tarif_box.box_delivery_marketplace_coef_expr; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_marketplace_coef_expr IS 'Формула или коэффициент расчета доставки короба для модели Marketplace (FBS).';


--
-- Name: COLUMN wb_tarif_box.box_delivery_marketplace_liter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_delivery_marketplace_liter IS 'Стоимость каждого дополнительного литра объема для Marketplace (FBS). Используется в calculate_logistics_cost().';


--
-- Name: COLUMN wb_tarif_box.box_storage_base; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_storage_base IS 'Базовая стоимость хранения короба на складе WB.';


--
-- Name: COLUMN wb_tarif_box.box_storage_coef_expr; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_storage_coef_expr IS 'Формула или коэффициент расчета хранения короба на складе WB.';


--
-- Name: COLUMN wb_tarif_box.box_storage_liter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.wb_tarif_box.box_storage_liter IS 'Стоимость хранения каждого дополнительного литра объема товара.';


--
-- Name: wb_tarif_box_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wb_tarif_box_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wb_tarif_box_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wb_tarif_box_id_seq OWNED BY public.wb_tarif_box.id;


--
-- Name: zennodata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.zennodata (
    id integer NOT NULL,
    type text NOT NULL,
    data text NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    expires_at timestamp without time zone
);


--
-- Name: zennodata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.zennodata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: zennodata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.zennodata_id_seq OWNED BY public.zennodata.id;


--
-- Name: article_events; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.article_events (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    article text NOT NULL,
    event_type text NOT NULL,
    event_time timestamp with time zone DEFAULT now() NOT NULL,
    import_log_id bigint,
    comment text,
    CONSTRAINT chk_article_events_type CHECK ((event_type = ANY (ARRAY['appeared'::text, 'disappeared'::text])))
);


--
-- Name: TABLE article_events; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.article_events IS 'События по артикулам поставщиков: появился или пропал';


--
-- Name: COLUMN article_events.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.id IS 'Технический ID события';


--
-- Name: COLUMN article_events.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.supplier_id IS 'ID поставщика из public.suppliers';


--
-- Name: COLUMN article_events.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.article IS 'Артикул товара';


--
-- Name: COLUMN article_events.event_type; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.event_type IS 'Тип события: appeared или disappeared';


--
-- Name: COLUMN article_events.event_time; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.event_time IS 'Дата и время фиксации события';


--
-- Name: COLUMN article_events.import_log_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.import_log_id IS 'Ссылка на запись в import_log, в рамках которой зафиксировано событие';


--
-- Name: COLUMN article_events.comment; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.article_events.comment IS 'Дополнительный комментарий';


--
-- Name: article_events_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.article_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: article_events_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.article_events_id_seq OWNED BY sima_land.article_events.id;


--
-- Name: current_articles; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.current_articles (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    article text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    first_final_price numeric(10,2),
    first_retail_price numeric(10,2),
    first_wholesale_price numeric(10,2)
);


--
-- Name: TABLE current_articles; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.current_articles IS 'Текущее состояние артикулов поставщиков';


--
-- Name: COLUMN current_articles.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.id IS 'Технический ID записи';


--
-- Name: COLUMN current_articles.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.supplier_id IS 'ID поставщика из public.suppliers';


--
-- Name: COLUMN current_articles.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.article IS 'Артикул товара';


--
-- Name: COLUMN current_articles.is_active; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.is_active IS 'Признак, что артикул присутствует в последней актуальной выгрузке';


--
-- Name: COLUMN current_articles.first_seen_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.first_seen_at IS 'Дата и время первого появления артикула';


--
-- Name: COLUMN current_articles.last_seen_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.last_seen_at IS 'Дата и время последнего появления артикула в выгрузке';


--
-- Name: COLUMN current_articles.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.created_at IS 'Дата и время создания записи';


--
-- Name: COLUMN current_articles.updated_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.updated_at IS 'Дата и время последнего обновления записи';


--
-- Name: COLUMN current_articles.first_final_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.first_final_price IS 'Финальная цена товара при первом появлении артикула у поставщика';


--
-- Name: COLUMN current_articles.first_retail_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.first_retail_price IS 'Розничная цена товара при первом появлении артикула у поставщика';


--
-- Name: COLUMN current_articles.first_wholesale_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.current_articles.first_wholesale_price IS 'Оптовая цена товара при первом появлении артикула у поставщика';


--
-- Name: current_articles_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.current_articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: current_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.current_articles_id_seq OWNED BY sima_land.current_articles.id;


--
-- Name: import_log; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.import_log (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    source_url text NOT NULL,
    local_file_path text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    status text NOT NULL,
    rows_in_staging bigint,
    rows_in_products bigint,
    file_size_bytes bigint,
    error_message text
);


--
-- Name: TABLE import_log; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.import_log IS 'Лог загрузок CSV-файлов поставщиков';


--
-- Name: COLUMN import_log.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.id IS 'ID записи лога';


--
-- Name: COLUMN import_log.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.supplier_id IS 'ID поставщика из public.suppliers';


--
-- Name: COLUMN import_log.source_url; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.source_url IS 'URL исходного CSV-файла';


--
-- Name: COLUMN import_log.local_file_path; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.local_file_path IS 'Локальный путь к скачанному файлу';


--
-- Name: COLUMN import_log.started_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.started_at IS 'Время начала загрузки';


--
-- Name: COLUMN import_log.finished_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.finished_at IS 'Время окончания загрузки';


--
-- Name: COLUMN import_log.status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.status IS 'Статус загрузки: in_progress / success / error';


--
-- Name: COLUMN import_log.rows_in_staging; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.rows_in_staging IS 'Количество строк, загруженных в staging';


--
-- Name: COLUMN import_log.rows_in_products; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.rows_in_products IS 'Количество строк, загруженных в основную таблицу';


--
-- Name: COLUMN import_log.file_size_bytes; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.file_size_bytes IS 'Размер файла в байтах';


--
-- Name: COLUMN import_log.error_message; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.import_log.error_message IS 'Текст ошибки, если загрузка завершилась с ошибкой';


--
-- Name: import_log_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.import_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_log_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.import_log_id_seq OWNED BY sima_land.import_log.id;


--
-- Name: invoice_items; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.invoice_items (
    id bigint NOT NULL,
    invoice_id bigint NOT NULL,
    attachment_id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    row_num integer,
    barcode text,
    article text,
    product_name text,
    qty numeric(12,3),
    unit_name text,
    price_before_discount numeric(12,2),
    amount_before_discount numeric(12,2),
    discount_amount numeric(12,2),
    price_after_discount numeric(12,2),
    total_amount numeric(12,2),
    volume_dm3 numeric(12,5),
    delivery_cost numeric(12,2),
    matched_product_id bigint,
    match_status text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE invoice_items; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.invoice_items IS 'Товарные строки из счетов Сима-ленд';


--
-- Name: COLUMN invoice_items.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.id IS 'ID строки счета';


--
-- Name: COLUMN invoice_items.invoice_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.invoice_id IS 'ID счета из sima_land.invoices';


--
-- Name: COLUMN invoice_items.attachment_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.attachment_id IS 'ID файла-вложения';


--
-- Name: COLUMN invoice_items.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.supplier_id IS 'ID поставщика';


--
-- Name: COLUMN invoice_items.row_num; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.row_num IS 'Номер строки в счете';


--
-- Name: COLUMN invoice_items.barcode; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.barcode IS 'Штрихкод товара';


--
-- Name: COLUMN invoice_items.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.article IS 'Артикул Сима-ленд';


--
-- Name: COLUMN invoice_items.product_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.product_name IS 'Название товара из счета';


--
-- Name: COLUMN invoice_items.qty; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.qty IS 'Количество товара';


--
-- Name: COLUMN invoice_items.unit_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.unit_name IS 'Единица измерения';


--
-- Name: COLUMN invoice_items.price_before_discount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.price_before_discount IS 'Цена товара до скидки';


--
-- Name: COLUMN invoice_items.amount_before_discount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.amount_before_discount IS 'Сумма строки до скидки';


--
-- Name: COLUMN invoice_items.discount_amount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.discount_amount IS 'Сумма скидки или наценки';


--
-- Name: COLUMN invoice_items.price_after_discount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.price_after_discount IS 'Цена товара после скидки';


--
-- Name: COLUMN invoice_items.total_amount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.total_amount IS 'Итоговая сумма строки';


--
-- Name: COLUMN invoice_items.volume_dm3; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.volume_dm3 IS 'Объем товара в дм3';


--
-- Name: COLUMN invoice_items.delivery_cost; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.delivery_cost IS 'Стоимость доставки по строке';


--
-- Name: COLUMN invoice_items.matched_product_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.matched_product_id IS 'ID товара из sima_land.sima_products';


--
-- Name: COLUMN invoice_items.match_status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.match_status IS 'Статус сопоставления с sima_products: matched / not_found';


--
-- Name: COLUMN invoice_items.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoice_items.created_at IS 'Дата создания записи';


--
-- Name: invoice_items_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.invoice_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoice_items_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.invoice_items_id_seq OWNED BY sima_land.invoice_items.id;


--
-- Name: invoices; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.invoices (
    id bigint NOT NULL,
    attachment_id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    invoice_number text,
    invoice_date date,
    contract_number text,
    supplier_name text,
    buyer_name text,
    total_amount numeric(12,2),
    vat_amount numeric(12,2),
    items_count integer,
    created_at timestamp with time zone DEFAULT now(),
    truestat_sync_date timestamp without time zone
);


--
-- Name: TABLE invoices; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.invoices IS 'Счета от поставщика Сима-ленд';


--
-- Name: COLUMN invoices.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.id IS 'ID счета';


--
-- Name: COLUMN invoices.attachment_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.attachment_id IS 'ID файла-вложения, из которого загружен счет';


--
-- Name: COLUMN invoices.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.supplier_id IS 'ID поставщика';


--
-- Name: COLUMN invoices.invoice_number; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.invoice_number IS 'Номер счета';


--
-- Name: COLUMN invoices.invoice_date; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.invoice_date IS 'Дата счета';


--
-- Name: COLUMN invoices.contract_number; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.contract_number IS 'Номер договора из счета';


--
-- Name: COLUMN invoices.supplier_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.supplier_name IS 'Название поставщика из счета';


--
-- Name: COLUMN invoices.buyer_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.buyer_name IS 'Название покупателя из счета';


--
-- Name: COLUMN invoices.total_amount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.total_amount IS 'Итоговая сумма счета к оплате';


--
-- Name: COLUMN invoices.vat_amount; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.vat_amount IS 'Сумма НДС по счету';


--
-- Name: COLUMN invoices.items_count; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.items_count IS 'Количество товарных позиций в счете';


--
-- Name: COLUMN invoices.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.created_at IS 'Дата создания записи';


--
-- Name: COLUMN invoices.truestat_sync_date; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.invoices.truestat_sync_date IS 'Дата и время успешной выгрузки всех товаров счета в сервис TrueStat. Если NULL — счет еще не выгружен.';


--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.invoices_id_seq OWNED BY sima_land.invoices.id;


--
-- Name: mail_import_attachments; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.mail_import_attachments (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    attachment_name text,
    attachment_ext text,
    file_hash text,
    local_path text,
    download_status text,
    parse_status text,
    rows_loaded integer,
    error_stage text,
    error_text text,
    created_at timestamp with time zone DEFAULT now(),
    parse_error_text text
);


--
-- Name: TABLE mail_import_attachments; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.mail_import_attachments IS 'Вложения писем';


--
-- Name: COLUMN mail_import_attachments.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.id IS 'ID вложения';


--
-- Name: COLUMN mail_import_attachments.message_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.message_id IS 'Ссылка на письмо';


--
-- Name: COLUMN mail_import_attachments.attachment_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.attachment_name IS 'Имя файла';


--
-- Name: COLUMN mail_import_attachments.attachment_ext; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.attachment_ext IS 'Расширение файла';


--
-- Name: COLUMN mail_import_attachments.file_hash; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.file_hash IS 'Хэш файла (защита от дублей)';


--
-- Name: COLUMN mail_import_attachments.local_path; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.local_path IS 'Путь к файлу';


--
-- Name: COLUMN mail_import_attachments.download_status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.download_status IS 'Статус скачивания';


--
-- Name: COLUMN mail_import_attachments.parse_status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.parse_status IS 'Статус разбора';


--
-- Name: COLUMN mail_import_attachments.rows_loaded; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.rows_loaded IS 'Количество загруженных строк';


--
-- Name: COLUMN mail_import_attachments.error_stage; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.error_stage IS 'Этап ошибки';


--
-- Name: COLUMN mail_import_attachments.error_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.error_text IS 'Текст ошибки';


--
-- Name: COLUMN mail_import_attachments.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.created_at IS 'Дата создания';


--
-- Name: COLUMN mail_import_attachments.parse_error_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_attachments.parse_error_text IS 'Текст ошибки парсинга файла';


--
-- Name: mail_import_attachments_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.mail_import_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_import_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.mail_import_attachments_id_seq OWNED BY sima_land.mail_import_attachments.id;


--
-- Name: mail_import_messages; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.mail_import_messages (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    gmail_message_id text NOT NULL,
    thread_id text,
    sender_email text,
    subject text,
    received_at timestamp with time zone,
    attachments_count integer,
    processing_status text,
    error_stage text,
    error_text text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE mail_import_messages; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.mail_import_messages IS 'Журнал писем из Gmail';


--
-- Name: COLUMN mail_import_messages.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.id IS 'ID записи';


--
-- Name: COLUMN mail_import_messages.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.supplier_id IS 'ID поставщика';


--
-- Name: COLUMN mail_import_messages.gmail_message_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.gmail_message_id IS 'ID письма в Gmail (уникальный)';


--
-- Name: COLUMN mail_import_messages.thread_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.thread_id IS 'ID цепочки письма';


--
-- Name: COLUMN mail_import_messages.sender_email; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.sender_email IS 'Email отправителя';


--
-- Name: COLUMN mail_import_messages.subject; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.subject IS 'Тема письма';


--
-- Name: COLUMN mail_import_messages.received_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.received_at IS 'Дата получения письма';


--
-- Name: COLUMN mail_import_messages.attachments_count; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.attachments_count IS 'Количество вложений';


--
-- Name: COLUMN mail_import_messages.processing_status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.processing_status IS 'Статус обработки';


--
-- Name: COLUMN mail_import_messages.error_stage; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.error_stage IS 'Этап ошибки';


--
-- Name: COLUMN mail_import_messages.error_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.error_text IS 'Текст ошибки';


--
-- Name: COLUMN mail_import_messages.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_import_messages.created_at IS 'Дата создания записи';


--
-- Name: mail_import_messages_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.mail_import_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_import_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.mail_import_messages_id_seq OWNED BY sima_land.mail_import_messages.id;


--
-- Name: mail_report_rows_raw; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.mail_report_rows_raw (
    id bigint NOT NULL,
    attachment_id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    report_date_from date,
    report_date_to date,
    section_name text,
    article_raw text,
    product_name_raw text,
    qty_raw text,
    unit_cost_raw text,
    total_cost_raw text,
    row_error_flag boolean DEFAULT false,
    row_error_text text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE mail_report_rows_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.mail_report_rows_raw IS 'Сырые строки из файлов';


--
-- Name: COLUMN mail_report_rows_raw.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.id IS 'ID строки';


--
-- Name: COLUMN mail_report_rows_raw.attachment_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.attachment_id IS 'Ссылка на файл';


--
-- Name: COLUMN mail_report_rows_raw.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.supplier_id IS 'ID поставщика';


--
-- Name: COLUMN mail_report_rows_raw.report_date_from; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.report_date_from IS 'Дата начала периода';


--
-- Name: COLUMN mail_report_rows_raw.report_date_to; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.report_date_to IS 'Дата окончания периода';


--
-- Name: COLUMN mail_report_rows_raw.section_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.section_name IS 'Раздел отчёта';


--
-- Name: COLUMN mail_report_rows_raw.article_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.article_raw IS 'Артикул как в файле';


--
-- Name: COLUMN mail_report_rows_raw.product_name_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.product_name_raw IS 'Название как в файле';


--
-- Name: COLUMN mail_report_rows_raw.qty_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.qty_raw IS 'Количество как текст';


--
-- Name: COLUMN mail_report_rows_raw.unit_cost_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.unit_cost_raw IS 'Цена за единицу как текст';


--
-- Name: COLUMN mail_report_rows_raw.total_cost_raw; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.total_cost_raw IS 'Сумма как текст';


--
-- Name: COLUMN mail_report_rows_raw.row_error_flag; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.row_error_flag IS 'Флаг ошибки строки';


--
-- Name: COLUMN mail_report_rows_raw.row_error_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.row_error_text IS 'Описание ошибки';


--
-- Name: COLUMN mail_report_rows_raw.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.mail_report_rows_raw.created_at IS 'Дата создания';


--
-- Name: mail_report_rows_raw_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.mail_report_rows_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mail_report_rows_raw_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.mail_report_rows_raw_id_seq OWNED BY sima_land.mail_report_rows_raw.id;


--
-- Name: sima_products; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.sima_products (
    id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    product_name text,
    main_category text,
    main_category_id text,
    brand text,
    article text,
    is_bestseller text,
    is_new text,
    is_preorder text,
    product_length text,
    product_width text,
    product_height text,
    package_length text,
    package_width text,
    package_height text,
    min_order_qty text,
    order_multiple text,
    unit_name text,
    weight_grams text,
    country text,
    description_html text,
    main_photo_url text,
    properties_text text,
    extra_photo_urls text,
    marking text,
    all_categories text,
    package_volume text,
    volume text,
    load_date date DEFAULT CURRENT_DATE NOT NULL,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    is_in_wb boolean,
    is_in_brendwall_import boolean,
    checked_in_brendwall_at timestamp with time zone,
    final_price numeric(10,2),
    retail_price numeric(10,2),
    wholesale_price numeric(10,2),
    free_stock integer
);


--
-- Name: TABLE sima_products; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.sima_products IS 'Товары поставщика Сима Лэнд (актуальная выгрузка CSV)';


--
-- Name: COLUMN sima_products.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.id IS 'Технический ID записи';


--
-- Name: COLUMN sima_products.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.supplier_id IS 'ID поставщика из public.suppliers';


--
-- Name: COLUMN sima_products.product_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.product_name IS 'Наименование товара';


--
-- Name: COLUMN sima_products.main_category; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.main_category IS 'Основная категория';


--
-- Name: COLUMN sima_products.main_category_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.main_category_id IS 'ID основной категории';


--
-- Name: COLUMN sima_products.brand; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.brand IS 'Торговая марка';


--
-- Name: COLUMN sima_products.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.article IS 'Артикул товара';


--
-- Name: COLUMN sima_products.is_bestseller; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.is_bestseller IS 'Флаг хит продаж';


--
-- Name: COLUMN sima_products.is_new; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.is_new IS 'Флаг новинка';


--
-- Name: COLUMN sima_products.is_preorder; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.is_preorder IS 'Флаг под заказ';


--
-- Name: COLUMN sima_products.product_length; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.product_length IS 'Длина товара';


--
-- Name: COLUMN sima_products.product_width; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.product_width IS 'Ширина товара';


--
-- Name: COLUMN sima_products.product_height; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.product_height IS 'Высота товара';


--
-- Name: COLUMN sima_products.package_length; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.package_length IS 'Длина упаковки';


--
-- Name: COLUMN sima_products.package_width; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.package_width IS 'Ширина упаковки';


--
-- Name: COLUMN sima_products.package_height; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.package_height IS 'Высота упаковки';


--
-- Name: COLUMN sima_products.min_order_qty; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.min_order_qty IS 'Минимум для заказа';


--
-- Name: COLUMN sima_products.order_multiple; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.order_multiple IS 'Кратность заказа';


--
-- Name: COLUMN sima_products.unit_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.unit_name IS 'Единица измерения';


--
-- Name: COLUMN sima_products.weight_grams; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.weight_grams IS 'Вес в граммах';


--
-- Name: COLUMN sima_products.country; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.country IS 'Страна производства';


--
-- Name: COLUMN sima_products.description_html; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.description_html IS 'Описание товара (HTML)';


--
-- Name: COLUMN sima_products.main_photo_url; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.main_photo_url IS 'Ссылка на основное фото';


--
-- Name: COLUMN sima_products.properties_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.properties_text IS 'Свойства товара';


--
-- Name: COLUMN sima_products.extra_photo_urls; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.extra_photo_urls IS 'Ссылки на дополнительные фото';


--
-- Name: COLUMN sima_products.marking; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.marking IS 'Маркировка товара';


--
-- Name: COLUMN sima_products.all_categories; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.all_categories IS 'Все категории (иерархия)';


--
-- Name: COLUMN sima_products.package_volume; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.package_volume IS 'Объем упаковки';


--
-- Name: COLUMN sima_products.volume; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.volume IS 'Объем товара';


--
-- Name: COLUMN sima_products.load_date; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.load_date IS 'Дата загрузки файла';


--
-- Name: COLUMN sima_products.loaded_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.loaded_at IS 'Дата и время загрузки записи';


--
-- Name: COLUMN sima_products.is_in_wb; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.is_in_wb IS 'Признак, что артикул найден в public.wb_cards (с учетом vendorcode_base)';


--
-- Name: COLUMN sima_products.is_in_brendwall_import; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.is_in_brendwall_import IS 'Признак, что артикул есть в файле import_brendwall.xlsx и уже отправлялся на загрузку в WB';


--
-- Name: COLUMN sima_products.checked_in_brendwall_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.checked_in_brendwall_at IS 'Дата и время последней проверки по файлу import_brendwall.xlsx';


--
-- Name: COLUMN sima_products.final_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.final_price IS 'Финальная цена';


--
-- Name: COLUMN sima_products.retail_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.retail_price IS 'Цена розничная';


--
-- Name: COLUMN sima_products.wholesale_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.wholesale_price IS 'Цена оптовая';


--
-- Name: COLUMN sima_products.free_stock; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_products.free_stock IS 'Остаток свободный';


--
-- Name: products_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.products_id_seq OWNED BY sima_land.sima_products.id;


--
-- Name: service_costs_fact; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.service_costs_fact (
    id bigint NOT NULL,
    attachment_id bigint NOT NULL,
    supplier_id bigint NOT NULL,
    article text,
    matched_product_id bigint,
    match_status text,
    report_date_from date,
    report_date_to date,
    service_type text,
    qty numeric,
    unit_cost numeric,
    total_cost numeric,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE service_costs_fact; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.service_costs_fact IS 'Факты расходов по услугам';


--
-- Name: COLUMN service_costs_fact.id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.id IS 'ID записи';


--
-- Name: COLUMN service_costs_fact.attachment_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.attachment_id IS 'Ссылка на файл';


--
-- Name: COLUMN service_costs_fact.supplier_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.supplier_id IS 'ID поставщика';


--
-- Name: COLUMN service_costs_fact.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.article IS 'Нормализованный артикул';


--
-- Name: COLUMN service_costs_fact.matched_product_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.matched_product_id IS 'ID товара из sima_products';


--
-- Name: COLUMN service_costs_fact.match_status; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.match_status IS 'Статус сопоставления';


--
-- Name: COLUMN service_costs_fact.report_date_from; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.report_date_from IS 'Начало периода';


--
-- Name: COLUMN service_costs_fact.report_date_to; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.report_date_to IS 'Конец периода';


--
-- Name: COLUMN service_costs_fact.service_type; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.service_type IS 'Тип услуги';


--
-- Name: COLUMN service_costs_fact.qty; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.qty IS 'Количество';


--
-- Name: COLUMN service_costs_fact.unit_cost; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.unit_cost IS 'Цена за единицу';


--
-- Name: COLUMN service_costs_fact.total_cost; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.total_cost IS 'Общая сумма';


--
-- Name: COLUMN service_costs_fact.created_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.service_costs_fact.created_at IS 'Дата создания';


--
-- Name: service_costs_fact_id_seq; Type: SEQUENCE; Schema: sima_land; Owner: -
--

CREATE SEQUENCE sima_land.service_costs_fact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: service_costs_fact_id_seq; Type: SEQUENCE OWNED BY; Schema: sima_land; Owner: -
--

ALTER SEQUENCE sima_land.service_costs_fact_id_seq OWNED BY sima_land.service_costs_fact.id;


--
-- Name: sima_staging; Type: TABLE; Schema: sima_land; Owner: -
--

CREATE TABLE sima_land.sima_staging (
    product_name text,
    main_category text,
    main_category_id text,
    brand text,
    article text,
    is_bestseller text,
    is_new text,
    is_preorder text,
    product_length text,
    product_width text,
    product_height text,
    package_length text,
    package_width text,
    package_height text,
    min_order_qty text,
    order_multiple text,
    unit_name text,
    weight_grams text,
    country text,
    free_stock text,
    description_html text,
    final_price text,
    retail_price text,
    wholesale_price text,
    main_photo_url text,
    properties_text text,
    extra_photo_urls text,
    marking text,
    all_categories text,
    package_volume text,
    volume text,
    loaded_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE sima_staging; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON TABLE sima_land.sima_staging IS 'Временная staging-таблица для загрузки CSV поставщика Сима Лэнд';


--
-- Name: COLUMN sima_staging.product_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.product_name IS 'Наименование товара';


--
-- Name: COLUMN sima_staging.main_category; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.main_category IS 'Основная категория';


--
-- Name: COLUMN sima_staging.main_category_id; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.main_category_id IS 'ID основной категории';


--
-- Name: COLUMN sima_staging.brand; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.brand IS 'Торговая марка';


--
-- Name: COLUMN sima_staging.article; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.article IS 'Артикул товара';


--
-- Name: COLUMN sima_staging.is_bestseller; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.is_bestseller IS 'Флаг хит продаж';


--
-- Name: COLUMN sima_staging.is_new; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.is_new IS 'Флаг новинка';


--
-- Name: COLUMN sima_staging.is_preorder; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.is_preorder IS 'Флаг под заказ';


--
-- Name: COLUMN sima_staging.product_length; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.product_length IS 'Длина товара';


--
-- Name: COLUMN sima_staging.product_width; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.product_width IS 'Ширина товара';


--
-- Name: COLUMN sima_staging.product_height; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.product_height IS 'Высота товара';


--
-- Name: COLUMN sima_staging.package_length; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.package_length IS 'Длина упаковки';


--
-- Name: COLUMN sima_staging.package_width; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.package_width IS 'Ширина упаковки';


--
-- Name: COLUMN sima_staging.package_height; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.package_height IS 'Высота упаковки';


--
-- Name: COLUMN sima_staging.min_order_qty; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.min_order_qty IS 'Минимум для заказа';


--
-- Name: COLUMN sima_staging.order_multiple; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.order_multiple IS 'Кратность заказа';


--
-- Name: COLUMN sima_staging.unit_name; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.unit_name IS 'Единица измерения';


--
-- Name: COLUMN sima_staging.weight_grams; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.weight_grams IS 'Вес в граммах';


--
-- Name: COLUMN sima_staging.country; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.country IS 'Страна производства';


--
-- Name: COLUMN sima_staging.free_stock; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.free_stock IS 'Остаток свободный';


--
-- Name: COLUMN sima_staging.description_html; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.description_html IS 'Описание товара';


--
-- Name: COLUMN sima_staging.final_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.final_price IS 'Финальная цена';


--
-- Name: COLUMN sima_staging.retail_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.retail_price IS 'Цена розничная';


--
-- Name: COLUMN sima_staging.wholesale_price; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.wholesale_price IS 'Цена оптовая';


--
-- Name: COLUMN sima_staging.main_photo_url; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.main_photo_url IS 'Ссылка на основное фото';


--
-- Name: COLUMN sima_staging.properties_text; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.properties_text IS 'Свойства товара';


--
-- Name: COLUMN sima_staging.extra_photo_urls; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.extra_photo_urls IS 'Ссылки на дополнительные фотографии';


--
-- Name: COLUMN sima_staging.marking; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.marking IS 'Маркировка';


--
-- Name: COLUMN sima_staging.all_categories; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.all_categories IS 'Все категории товара';


--
-- Name: COLUMN sima_staging.package_volume; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.package_volume IS 'Объем упаковки';


--
-- Name: COLUMN sima_staging.volume; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.volume IS 'Объем товара';


--
-- Name: COLUMN sima_staging.loaded_at; Type: COMMENT; Schema: sima_land; Owner: -
--

COMMENT ON COLUMN sima_land.sima_staging.loaded_at IS 'Дата и время загрузки строки в staging';


--
-- Name: product_prices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_prices ALTER COLUMN id SET DEFAULT nextval('public.product_prices_id_seq'::regclass);


--
-- Name: suppliers supplier_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN supplier_id SET DEFAULT nextval('public.suppliers_supplier_id_seq'::regclass);


--
-- Name: wb_commission id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_commission ALTER COLUMN id SET DEFAULT nextval('public.wb_commission_id_seq'::regclass);


--
-- Name: wb_tarif_box id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_tarif_box ALTER COLUMN id SET DEFAULT nextval('public.wb_tarif_box_id_seq'::regclass);


--
-- Name: zennodata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zennodata ALTER COLUMN id SET DEFAULT nextval('public.zennodata_id_seq'::regclass);


--
-- Name: article_events id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.article_events ALTER COLUMN id SET DEFAULT nextval('sima_land.article_events_id_seq'::regclass);


--
-- Name: current_articles id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.current_articles ALTER COLUMN id SET DEFAULT nextval('sima_land.current_articles_id_seq'::regclass);


--
-- Name: import_log id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.import_log ALTER COLUMN id SET DEFAULT nextval('sima_land.import_log_id_seq'::regclass);


--
-- Name: invoice_items id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items ALTER COLUMN id SET DEFAULT nextval('sima_land.invoice_items_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoices ALTER COLUMN id SET DEFAULT nextval('sima_land.invoices_id_seq'::regclass);


--
-- Name: mail_import_attachments id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_import_attachments ALTER COLUMN id SET DEFAULT nextval('sima_land.mail_import_attachments_id_seq'::regclass);


--
-- Name: mail_import_messages id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_import_messages ALTER COLUMN id SET DEFAULT nextval('sima_land.mail_import_messages_id_seq'::regclass);


--
-- Name: mail_report_rows_raw id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_report_rows_raw ALTER COLUMN id SET DEFAULT nextval('sima_land.mail_report_rows_raw_id_seq'::regclass);


--
-- Name: service_costs_fact id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.service_costs_fact ALTER COLUMN id SET DEFAULT nextval('sima_land.service_costs_fact_id_seq'::regclass);


--
-- Name: sima_products id; Type: DEFAULT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.sima_products ALTER COLUMN id SET DEFAULT nextval('sima_land.products_id_seq'::regclass);


--
-- Name: product_prices product_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_prices
    ADD CONSTRAINT product_prices_pkey PRIMARY KEY (id);


--
-- Name: supplier_stock supplier_stock_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_stock
    ADD CONSTRAINT supplier_stock_pk PRIMARY KEY (vendor_code);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (supplier_id);


--
-- Name: suppliers suppliers_supplier_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_supplier_code_key UNIQUE (supplier_code);


--
-- Name: wb_tarif_box unique_warehouse_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_tarif_box
    ADD CONSTRAINT unique_warehouse_name UNIQUE (warehouse_name);


--
-- Name: wb_cards wb_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_cards
    ADD CONSTRAINT wb_cards_pkey PRIMARY KEY (nmid);


--
-- Name: wb_commission wb_commission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_commission
    ADD CONSTRAINT wb_commission_pkey PRIMARY KEY (id);


--
-- Name: wb_price_unit wb_price_unit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_price_unit
    ADD CONSTRAINT wb_price_unit_pkey PRIMARY KEY (nmid);


--
-- Name: wb_tarif_box wb_tarif_box_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wb_tarif_box
    ADD CONSTRAINT wb_tarif_box_pkey PRIMARY KEY (id);


--
-- Name: zennodata zennodata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.zennodata
    ADD CONSTRAINT zennodata_pkey PRIMARY KEY (id);


--
-- Name: article_events article_events_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.article_events
    ADD CONSTRAINT article_events_pkey PRIMARY KEY (id);


--
-- Name: current_articles current_articles_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.current_articles
    ADD CONSTRAINT current_articles_pkey PRIMARY KEY (id);


--
-- Name: import_log import_log_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.import_log
    ADD CONSTRAINT import_log_pkey PRIMARY KEY (id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: mail_import_attachments mail_import_attachments_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_import_attachments
    ADD CONSTRAINT mail_import_attachments_pkey PRIMARY KEY (id);


--
-- Name: mail_import_messages mail_import_messages_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_import_messages
    ADD CONSTRAINT mail_import_messages_pkey PRIMARY KEY (id);


--
-- Name: mail_report_rows_raw mail_report_rows_raw_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_report_rows_raw
    ADD CONSTRAINT mail_report_rows_raw_pkey PRIMARY KEY (id);


--
-- Name: sima_products products_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.sima_products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: service_costs_fact service_costs_fact_pkey; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.service_costs_fact
    ADD CONSTRAINT service_costs_fact_pkey PRIMARY KEY (id);


--
-- Name: current_articles uq_current_articles_supplier_article; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.current_articles
    ADD CONSTRAINT uq_current_articles_supplier_article UNIQUE (supplier_id, article);


--
-- Name: invoices uq_invoices_supplier_invoice_number; Type: CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoices
    ADD CONSTRAINT uq_invoices_supplier_invoice_number UNIQUE (supplier_id, invoice_number);


--
-- Name: idx_article_events_article; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_article_events_article ON sima_land.article_events USING btree (article);


--
-- Name: idx_article_events_event_time; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_article_events_event_time ON sima_land.article_events USING btree (event_time);


--
-- Name: idx_article_events_event_type; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_article_events_event_type ON sima_land.article_events USING btree (event_type);


--
-- Name: idx_article_events_supplier_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_article_events_supplier_id ON sima_land.article_events USING btree (supplier_id);


--
-- Name: idx_current_articles_article; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_current_articles_article ON sima_land.current_articles USING btree (article);


--
-- Name: idx_current_articles_is_active; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_current_articles_is_active ON sima_land.current_articles USING btree (is_active);


--
-- Name: idx_current_articles_supplier_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_current_articles_supplier_id ON sima_land.current_articles USING btree (supplier_id);


--
-- Name: idx_fact_article; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_fact_article ON sima_land.service_costs_fact USING btree (article);


--
-- Name: idx_fact_product; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_fact_product ON sima_land.service_costs_fact USING btree (matched_product_id);


--
-- Name: idx_invoice_items_article; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoice_items_article ON sima_land.invoice_items USING btree (article);


--
-- Name: idx_invoice_items_invoice_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoice_items_invoice_id ON sima_land.invoice_items USING btree (invoice_id);


--
-- Name: idx_invoice_items_matched_product_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoice_items_matched_product_id ON sima_land.invoice_items USING btree (matched_product_id);


--
-- Name: idx_invoice_items_supplier_article; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoice_items_supplier_article ON sima_land.invoice_items USING btree (supplier_id, article);


--
-- Name: idx_invoices_attachment_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoices_attachment_id ON sima_land.invoices USING btree (attachment_id);


--
-- Name: idx_invoices_invoice_number; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoices_invoice_number ON sima_land.invoices USING btree (invoice_number);


--
-- Name: idx_invoices_supplier_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_invoices_supplier_id ON sima_land.invoices USING btree (supplier_id);


--
-- Name: idx_mail_attachment_hash; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_mail_attachment_hash ON sima_land.mail_import_attachments USING btree (file_hash);


--
-- Name: idx_mail_attachment_message_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_mail_attachment_message_id ON sima_land.mail_import_attachments USING btree (message_id);


--
-- Name: idx_rows_attachment_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE INDEX idx_rows_attachment_id ON sima_land.mail_report_rows_raw USING btree (attachment_id);


--
-- Name: uq_mail_import_messages_gmail_id; Type: INDEX; Schema: sima_land; Owner: -
--

CREATE UNIQUE INDEX uq_mail_import_messages_gmail_id ON sima_land.mail_import_messages USING btree (gmail_message_id);


--
-- Name: supplier_stock supplier_stock_supplier_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_stock
    ADD CONSTRAINT supplier_stock_supplier_fk FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: article_events fk_article_events_import_log; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.article_events
    ADD CONSTRAINT fk_article_events_import_log FOREIGN KEY (import_log_id) REFERENCES sima_land.import_log(id);


--
-- Name: article_events fk_article_events_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.article_events
    ADD CONSTRAINT fk_article_events_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: current_articles fk_current_articles_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.current_articles
    ADD CONSTRAINT fk_current_articles_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: service_costs_fact fk_fact_attachment; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.service_costs_fact
    ADD CONSTRAINT fk_fact_attachment FOREIGN KEY (attachment_id) REFERENCES sima_land.mail_import_attachments(id);


--
-- Name: service_costs_fact fk_fact_product; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.service_costs_fact
    ADD CONSTRAINT fk_fact_product FOREIGN KEY (matched_product_id) REFERENCES sima_land.sima_products(id);


--
-- Name: import_log fk_import_log_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.import_log
    ADD CONSTRAINT fk_import_log_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: invoice_items fk_invoice_items_attachment; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items
    ADD CONSTRAINT fk_invoice_items_attachment FOREIGN KEY (attachment_id) REFERENCES sima_land.mail_import_attachments(id);


--
-- Name: invoice_items fk_invoice_items_invoice; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items
    ADD CONSTRAINT fk_invoice_items_invoice FOREIGN KEY (invoice_id) REFERENCES sima_land.invoices(id);


--
-- Name: invoice_items fk_invoice_items_product; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items
    ADD CONSTRAINT fk_invoice_items_product FOREIGN KEY (matched_product_id) REFERENCES sima_land.sima_products(id);


--
-- Name: invoice_items fk_invoice_items_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoice_items
    ADD CONSTRAINT fk_invoice_items_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: invoices fk_invoices_attachment; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoices
    ADD CONSTRAINT fk_invoices_attachment FOREIGN KEY (attachment_id) REFERENCES sima_land.mail_import_attachments(id);


--
-- Name: invoices fk_invoices_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.invoices
    ADD CONSTRAINT fk_invoices_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- Name: mail_import_attachments fk_mail_attachment_message; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_import_attachments
    ADD CONSTRAINT fk_mail_attachment_message FOREIGN KEY (message_id) REFERENCES sima_land.mail_import_messages(id);


--
-- Name: mail_report_rows_raw fk_rows_attachment; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.mail_report_rows_raw
    ADD CONSTRAINT fk_rows_attachment FOREIGN KEY (attachment_id) REFERENCES sima_land.mail_import_attachments(id);


--
-- Name: sima_products fk_sima_products_supplier; Type: FK CONSTRAINT; Schema: sima_land; Owner: -
--

ALTER TABLE ONLY sima_land.sima_products
    ADD CONSTRAINT fk_sima_products_supplier FOREIGN KEY (supplier_id) REFERENCES public.suppliers(supplier_id);


--
-- PostgreSQL database dump complete
--

\unrestrict 9yns6caYrXgcfPR2DXdkKemABhg4ie26UZgdtIKz1JySWooXtnA2Dem1Q9J1DY5

