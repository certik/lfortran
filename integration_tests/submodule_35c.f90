submodule (submodule_35_mod) submodule_35_sub
  implicit none
contains
  pure module function pure_det(a) result(det)
    real(8), intent(in) :: a(:,:)
    real(8) :: det
    det = a(1,1)*a(2,2) - a(1,2)*a(2,1)
  end function pure_det
end submodule submodule_35_sub
