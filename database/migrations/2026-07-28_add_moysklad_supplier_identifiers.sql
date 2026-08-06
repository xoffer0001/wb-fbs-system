BEGIN;

ALTER TABLE public.suppliers
    ADD COLUMN moysklad_id uuid,
    ADD COLUMN moysklad_external_code text;

COMMENT ON COLUMN public.suppliers.moysklad_id IS
    'UUID контрагента-поставщика в МойСклад. Берется из product.supplier.meta.href или counterparty.id.';

COMMENT ON COLUMN public.suppliers.moysklad_external_code IS
    'Поле externalCode контрагента-поставщика в МойСклад. Используется как дополнительный идентификатор.';

CREATE UNIQUE INDEX suppliers_moysklad_id_uq
    ON public.suppliers (moysklad_id)
    WHERE moysklad_id IS NOT NULL;

CREATE UNIQUE INDEX suppliers_moysklad_external_code_uq
    ON public.suppliers (moysklad_external_code)
    WHERE moysklad_external_code IS NOT NULL;

COMMIT;
